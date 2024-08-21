FROM node:22.2.0-alpine as front
WORKDIR /app
COPY front/package*.json ./
RUN npm config set registry http://mirrors.cloud.tencent.com/npm
RUN npm install
COPY front/. .
RUN npm run generate

FROM golang:1.22.5-alpine as backend
ENV CGO_ENABLED 1
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk update --no-cache
RUN apk add build-base
WORKDIR /app
COPY backend/go.mod .
COPY backend/go.sum .
RUN go env -w GO111MODULE=on && go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN go mod tidy
COPY backend/. .
COPY --from=front /app/.output/public /app/public
RUN apk update --no-cache && apk add --no-cache tzdata
RUN go build -tags prod -ldflags="-s -w" -o /app/moments

FROM alpine
ARG VERSION
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk update --no-cache && apk add --no-cache ca-certificates
COPY --from=backend /usr/share/zoneinfo/Asia/Shanghai /usr/share/zoneinfo/Asia/Shanghai
ENV TZ Asia/Shanghai
WORKDIR /app/data
ENV VERSION $VERSION
COPY --from=backend /app/moments /app/moments
ENV PORT 3000
EXPOSE 3000
RUN chmod +x /app/moments
CMD ["/app/moments"]