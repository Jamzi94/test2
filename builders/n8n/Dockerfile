FROM n8nio/n8n:latest

USER root

# Install ffmpeg and clean up apk cache
RUN apk add --no-cache ffmpeg && rm -rf /var/cache/apk/*

USER node