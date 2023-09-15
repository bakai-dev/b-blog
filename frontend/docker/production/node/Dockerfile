FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app

USER node

COPY ./dist/frontend ./frontend

# RUN node dist/frontend/server/main.js

#HEALTHCHECK --interval=5s --timeout=5s --start-period=1s CMD curl --fail http://127.0.0.1:4000/health || exit 1
