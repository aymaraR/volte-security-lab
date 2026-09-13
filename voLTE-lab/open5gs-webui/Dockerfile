FROM node:18-bookworm-slim AS builder

RUN apt-get update && apt-get install -y git python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v2.8.0 https://github.com/open5gs/open5gs.git /open5gs

WORKDIR /open5gs/webui
RUN npm ci --no-optional
RUN npm run build

FROM node:18-bookworm-slim

WORKDIR /open5gs/webui
COPY --from=builder /open5gs/webui /open5gs/webui

EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
