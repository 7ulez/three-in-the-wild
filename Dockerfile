FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget unzip \
    && rm -rf /var/lib/apt/lists/*
RUN wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -O /tmp/g.zip \
    && unzip -q /tmp/g.zip -d /opt \
    && mv /opt/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot \
    && rm /tmp/g.zip
COPY . /game
WORKDIR /game
RUN godot --headless --path /game --import || true
ENV DATA_DIR=/data
VOLUME /data
EXPOSE 24680 24681
CMD ["godot", "--headless", "--path", "/game", "--", "--server"]
