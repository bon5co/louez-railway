# Louez wrapper for Railway. Upstream is a Next.js server (equipment-rental platform) that needs a MySQL URL, an S3 endpoint and
# an auth secret, listens on $PORT, and has no first account until someone registers in a browser: in standalone mode the first
# account becomes the owner and registration then closes, a race the first visitor wins. The wrapper runs the server on a private
# loopback port first, registers the owner from ADMIN_EMAIL and ADMIN_PASSWORD there, and only then starts the server on
# Railway's injected PORT, so the open sign-up page is never reachable from outside.
# upstream: Synapsr/Louez
FROM synapsr/louez:2.3.1@sha256:8b0b9271203174195f00215b61c8f6efa4a5aa3597bdd798ea7da6867c1d713a

COPY --chmod=0755 boot.sh /railway-boot.sh
COPY --chmod=0644 bootstrap.js /railway-bootstrap.js

# Louez runs as one store served from one origin (standalone) and serves product images
# same-origin from /files through its own S3 credentials, so the bucket stays private. S3 endpoint, keys and the database URL
# come from the template's variables.
ENV LOUEZ_MODE=standalone \
    AUTH_TRUST_HOST=true \
    S3_REGION=us-east-1 \
    S3_BUCKET=louez \
    S3_PUBLIC_URL=/files \
    PORT=8080
EXPOSE 8080
ENTRYPOINT ["/railway-boot.sh"]
CMD ["./docker/entrypoint.sh", "node", "apps/web/server.js"]
