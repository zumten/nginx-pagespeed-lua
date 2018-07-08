FROM alpine:3.7

RUN apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
        git

ENV NGINX_VERSION=1.15.1 \
    NPS_VERSION=1.13.35.2-stable \
    LUAJIT_VERSION=2.0.5 \
    LUA_NGINX_VERSION=0.10.13 \
    NGX_DEVEL_VERSION=0.3.0 \
    OPENSSL_VERSION=1.1.0e \
    BUILD_DIR=/tmp/build \
    BUILD_LUAJIT_DIR=/tmp/build/luajit \
    BUILD_NGINX_DIR=/tmp/build/nginx \
    BUILD_MODULE_DIR=/tmp/build/modules \
    NGINX_DIR=/etc/nginx \
    NGINX_CACHE_DIR=/data/nginx/cache

RUN mkdir -p ${BUILD_DIR}/luajit \
    && cd ${BUILD_DIR}/luajit \
    && wget -O luajit.tar.gz http://luajit.org/download/LuaJIT-${LUAJIT_VERSION}.tar.gz \
    && tar xvf luajit.tar.gz --strip-components=1 \
    && make PREFIX=/usr/local \
    && make install \
    && export LUAJIT_LIB=/usr/local/lib \
    && export LUAJIT_INC=`cd /usr/local/include/lua* && pwd`

RUN mkdir -p ${BUILD_MODULE_DIR} \
    && CONFIG_MODULES="" \
    && addModule() { \
        cd ${BUILD_MODULE_DIR} \
        && mkdir -p $2 && wget https://github.com/$1/$2/archive/$3.tar.gz -O $2.tar.gz && tar -zxf $2.tar.gz -C $2 --strip-components=1 && rm $2.tar.gz \
        && CONFIG_MODULES="${CONFIG_MODULES} --add-module=${BUILD_MODULE_DIR}/$2" \
        && cd $2 && git submodule update --init --recursive; \
    } \
    && addModule yaoweibin   ngx_http_substitutions_filter_module  master \
    && addModule google      ngx_brotli                            master \
    && addModule openresty   headers-more-nginx-module             v0.32 \
    && addModule simpl       ngx_devel_kit                         v${NGX_DEVEL_VERSION} \
    && addModule FRiCKLE     ngx_cache_purge                       2.3 \
    && addModule openresty   lua-nginx-module                      v${LUA_NGINX_VERSION} \
    && addModule apache      incubator-pagespeed-ngx               v${NPS_VERSION}

    #&& cd ${BUILD_DIR}/openssl && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    #    && tar xvf openssl-${OPENSSL_VERSION}.tar.gz --strip-components=1 \
    #&& cd ${BUILD_DIR}/pcre && wget https://ftp.pcre.org/pub/pcre/pcre-8.40.tar.gz \
    #    && tar xvf pcre-8.40.tar.gz --strip-components=1 \
    #&& cd ${BUILD_DIR}/zlib && wget http://www.zlib.net/zlib-1.2.11.tar.gz \
    #    && tar xvf zlib-1.2.11.tar.gz --strip-components=1 \
RUN cd ${BUILD_MODULE_DIR}/incubator-pagespeed-ngx \
     && NPS_RELEASE_NUMBER=${NPS_VERSION/beta/} \
     && NPS_RELEASE_NUMBER=${NPS_VERSION/stable/} \
     && psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz \
     && [ -e scripts/format_binary_url.sh ] && psol_url=$(sh scripts/format_binary_url.sh PSOL_BINARY_URL) \
     && wget ${psol_url} \
     && tar -xzvf $(basename ${psol_url})

RUN addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && mkdir -p ${BUILD_DIR}/nginx \
    && cd ${BUILD_DIR} \
	&& wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -O nginx.tar.gz \
	&& tar -zxC ${BUILD_DIR}/nginx -f nginx.tar.gz --strip-components=1 \
	&& rm nginx.tar.gz

#RUN mkdir -p ${BUILD_DIR}/{modules,nginx,openssl,pcre,zlib,luajit} \
#    && mkdir -p ${NGINX_DIR}/{cache/{client,fastcgi,proxy,uwsgi,scgi},lock,logs,modules,pid,sites,ssl} \
#    && cd ${BUILD_DIR}/nginx && wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
#        && tar xvf nginx-${NGINX_VERSION}.tar.gz --strip-components=1 \
#
#
#    && cd ${BUILD_DIR}/nginx

RUN CONFIG="\
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=${NGINX_DIR}/config/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=${NGINX_DIR}/pid/nginx.pid \
        --lock-path=${NGINX_DIR}/lock/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        ${CONFIG_MODULES} \
    "
            #--with-poll_module \
        #--with-http_degradation_module \
        #--with-google_perftools_module \
        #--with-pcre=${BUILD_DIR}/pcre \
        #--with-pcre-jit \
        #--with-zlib=${BUILD_DIR}/zlib \
        #--with-openssl=${BUILD_DIR}/openssl \

RUN cd ${BUILD_DIR}/nginx \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
