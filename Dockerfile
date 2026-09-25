FROM alpine:3.20
ENV APP_MODE=production
ENV SCAN_MARKER=marker-aaa-bbb-ccc
EXPOSE 8080
CMD ["sleep","infinity"]
