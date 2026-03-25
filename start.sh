#!/bin/bash

# 1. SETUP LOGS
touch /var/log/icecast2/access.log
touch /var/log/icecast2/error.log
touch /tmp/tunnel.log
touch /tmp/ffmpeg.log

# 2. GENERATE FFMPEG PLAYLIST (MP3 + WAV + SHUFFLE)
echo "Building Playlist..."
find /home/radio/music -type f \( -name "*.mp3" -o -name "*.wav" \) | shuf | sed "s/^/file '/;s/$/'/" > /home/radio/ffmpeg_list.txt

chmod 644 /home/radio/ffmpeg_list.txt
COUNT=$(wc -l < /home/radio/ffmpeg_list.txt)
echo "Found $COUNT tracks (MP3/WAV)."

# 3. START ICECAST
echo "Starting Icecast..."
icecast2 -c /home/radio/icecast.xml -b
sleep 5

# 4. START AUTO-DJ (FFMPEG)
echo "Starting FFmpeg Auto-DJ..."
while true; do
    # Stream the list
    ffmpeg -re -f concat -safe 0 -i /home/radio/ffmpeg_list.txt \
    -c:a libmp3lame -b:a 128k -content_type audio/mpeg \
    -f mp3 icecast://source:autodjpassword@localhost:7860/autodj >> /tmp/ffmpeg.log 2>&1
    
    echo "Playlist finished. Reshuffling..."
    
    # RE-SHUFFLE LOGIC
    find /home/radio/music -type f \( -name "*.mp3" -o -name "*.wav" \) | shuf | sed "s/^/file '/;s/$/'/" > /home/radio/ffmpeg_list.txt
    
    sleep 2
done &

# 5. START TUNNEL
echo "Starting Tunnel..."
bore local 8000 --to bore.pub > /tmp/tunnel.log 2>&1 &

# 6. GET PORT & PUBLISH IT
sleep 5
REMOTE_PORT=""
for i in {1..15}; do
    if [ -f /tmp/tunnel.log ]; then
        REMOTE_PORT=$(grep -o "bore.pub:[0-9]*" /tmp/tunnel.log | cut -d: -f2)
        if [ ! -z "$REMOTE_PORT" ]; then
            # --- NEW: Write the port to a webpage ---
            echo "<html><body style='background:#000; color:#0f0; font-family:monospace; font-size:3em; display:flex; justify-content:center; align-items:center; height:100vh; flex-direction:column;'><div>BUTT SERVER: bore.pub</div><div style='color:white; margin-top:20px;'>PORT: $REMOTE_PORT</div></body></html>" > /usr/share/icecast2/web/butt.html
            break
        fi
    fi
    sleep 1
done

echo "========================================="
echo "🔴 sSs RADIO ONLINE 🔴"
echo "-----------------------------------------"
echo "LIVE INPUT (BUTT):"
echo "Server: bore.pub"
echo "Port:   $REMOTE_PORT"
echo "Pass:   hacktheplanet"
echo "Mount:  /stream"
echo "-----------------------------------------"
echo "CHECK PORT HERE:"
echo "https://$SPACE_HOST/butt.html"
echo "========================================="

# 7. KEEP ALIVE
tail -f /var/log/icecast2/error.log /tmp/ffmpeg.log