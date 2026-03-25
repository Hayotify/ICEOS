FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
RUN apt-get update && apt-get install -y \
    icecast2 \
    ffmpeg \
    curl \
    tar \
    ca-certificates \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Bore
RUN curl -L -o bore.tar.gz https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz && \
    tar -xzf bore.tar.gz -C /usr/local/bin && \
    rm bore.tar.gz

# 3. Create 'radio' user
RUN useradd -m -d /home/radio -s /bin/bash radio

# 4. Setup Directories & Permissions
RUN mkdir -p /var/log/icecast2 && \
    chown -R radio:radio /var/log/icecast2 && \
    chown -R radio:radio /etc/icecast2 && \
    chown -R radio:radio /home/radio

# 5. Copy Files
COPY music /home/radio/music
COPY icecast.xml /home/radio/icecast.xml
COPY start.sh /start.sh

# 6. CRITICAL: Create the Status File for UptimeRobot
# We create it and make sure the radio user owns the web folder
RUN echo "SYSTEM ONLINE" > /usr/share/icecast2/web/status.txt && \
    chown -R radio:radio /usr/share/icecast2/web

# 7. Clean Configs
RUN dos2unix /home/radio/icecast.xml && \
    dos2unix /start.sh

# 8. Permissions
RUN chmod 644 /home/radio/icecast.xml && \
    chmod +x /start.sh && \
    chown radio:radio /start.sh

# 9. Final Permissions
RUN chown -R radio:radio /home/radio && \
    chown radio:radio /etc/icecast2/icecast.xml
    expose 7860

# 10. Launch
USER radio
WORKDIR /home/radio
CMD ["bash", "/start.sh"]