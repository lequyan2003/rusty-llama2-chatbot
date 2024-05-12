ARG RUST_VERSION=1.77.1
ARG APP_NAME=rusty_llama
ARG NODE_MAJOR=20
ARG MODEL_NAME=llama-2-7b-chat.ggmlv3.q2_K.bin

FROM node:${NODE_MAJOR} AS tailwind-build

WORKDIR /app
COPY src src
COPY input.css .
COPY tailwind.config.js .
COPY package.json .
RUN npm install
RUN npx tailwindcss -i ./input.css -o ./output.css

FROM rust:${RUST_VERSION}-slim-bullseye AS build
ARG APP_NAME
WORKDIR /app

RUN apt-get update
RUN apt-get install -y pkg-config openssl libssl-dev curl

COPY . .
COPY --from=tailwind-build /app/output.css /app/style/output.css
RUN rustup target add wasm32-unknown-unknown
RUN cargo install cargo-leptos
RUN cargo leptos build --release -vv

# RUN --mount=type=bind,source=src,target=src \
#     --mount=type=bind,source=Cargo.toml,target=Cargo.toml \
#     --mount=type=bind,source=Cargo.lock,target=Cargo.lock \
#     --mount=type=cache,target=/app/target/ \
#     --mount=type=cache,target=/usr/local/cargo/registry/ \
#     <<EOF
# set -e
# cargo build --locked --release
# cp ./target/release/$APP_NAME /bin/server
# EOF

FROM debian:bullseye-slim AS final
ARG APP_NAME
ARG MODEL_NAME

RUN apt-get update && apt-get install -y openssl

WORKDIR /app
COPY --from=build /app/$MODEL_NAME model
COPY --from=build /app/target/server/release/$APP_NAME server
COPY --from=build /app/target/site target/site

ENV MODEL_PATH=/app/model
ENV LEPTOS_SITE_ADDR=0.0.0.0:3000

ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

RUN chown -R appuser:appuser /app
RUN chmod -R 755 /app

USER appuser

# COPY --from=build /bin/server /bin/

EXPOSE 3000

# CMD ["/bin/server"]
CMD ["/app/server"]