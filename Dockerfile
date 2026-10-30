FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget unzip \
    && rm -rf /var/lib/apt/lists/*
# Godot-Download wird gegen die offizielle Prüfsumme (SHA512-SUMS.txt des Releases) geprüft
ARG GODOT_SHA512=fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a
RUN wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -O /tmp/g.zip \
    && echo "${GODOT_SHA512}  /tmp/g.zip" | sha512sum -c - \
    && unzip -q /tmp/g.zip -d /opt \
    && mv /opt/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot \
    && rm /tmp/g.zip
COPY . /game
WORKDIR /game
RUN godot --headless --path /game --import || true
RUN chmod -R a+rX /game && chmod +x /game/docker-entrypoint.sh
ENV DATA_DIR=/data HOME=/tmp
VOLUME /data
EXPOSE 24680 24681
# Läuft als Benutzer 99:100 statt root (änderbar über PUID/PGID)
ENTRYPOINT ["/game/docker-entrypoint.sh"]
CMD ["godot", "--headless", "--path", "/game", "--", "--server"]
