FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

ENV PORT=3333
EXPOSE 3333

CMD ["node", "server.js"]
