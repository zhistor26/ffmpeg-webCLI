# LazyCat embed image — static ffmpeg-webCLI PWA
# 微服无法直连 docker.io，使用懒猫镜像仓库
FROM registry.lazycat.cloud/snyh1010/library/nginx:54809b2f36d0ff38

RUN rm -f /etc/nginx/conf.d/default.conf

COPY lzc/images/nginx.conf /etc/nginx/conf.d/default.conf
COPY lzc/pack/docs.tar.gz /tmp/docs.tar.gz
RUN mkdir -p /usr/share/nginx/html \
 && tar -xzf /tmp/docs.tar.gz -C /usr/share/nginx/html --no-same-owner \
 && rm /tmp/docs.tar.gz

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
