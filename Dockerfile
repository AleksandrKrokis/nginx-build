FROM ubuntu:22.04 as stage

ARG NGINX_VERSION=1.25.5
ARG IP2LOCATION_C_VERSION=8.6.1
ARG IP2PROXY_C_VERSION=4.1.2
ARG IP2LOCATION_NGINX_VERSION=8.6.0
ARG IP2PROXY_NGINX_VERSION=8.1.1
ARG FIFTYONEDEGREES_NGINX_VERSION=3.2.21.1
ARG NGINX_CACHE_PURGE_VERSION=2.5.3
ARG NGINX_VTS_VERSION=0.2.2
ARG LUAJIT_VERSION=2.1-20231117
ARG LUA_NGINX_MODULE_VERSION=0.10.25
ARG LUA_RESTY_CORE_VERSION=0.1.27
ARG LUA_RESTY_LRUCACHE_VERSION=0.13

# Install required packages for development
RUN apt-get update -q \
  && apt-get install -yq \
  unzip \
  autoconf \
  build-essential \
  libtool \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  libgd-dev \
  zlib1g-dev \
  gcc \
  make \
  git \
  wget \
  curl \
  checkinstall

# Download and build LuaJIT
RUN cd /usr/local/src \
  && wget https://github.com/openresty/luajit2/archive/v${LUAJIT_VERSION}.tar.gz \
  && tar xzf v${LUAJIT_VERSION}.tar.gz \
  && cd luajit2-${LUAJIT_VERSION} \
  && make -j$(nproc) \
  && make install \
  && cd .. \
  && rm -rf luajit2-${LUAJIT_VERSION} v${LUAJIT_VERSION}.tar.gz

# Set LuaJIT paths
ENV LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_INC=/usr/local/include/luajit-2.1

# Download lua-resty-core and lua-resty-lrucache (required by core)
RUN cd /usr/local/src \
  && wget https://github.com/openresty/lua-resty-core/archive/v${LUA_RESTY_CORE_VERSION}.tar.gz \
  && tar xzf v${LUA_RESTY_CORE_VERSION}.tar.gz \
  && rm v${LUA_RESTY_CORE_VERSION}.tar.gz \
  && wget https://github.com/openresty/lua-resty-lrucache/archive/v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz \
  && tar xzf v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz \
  && rm v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz \
  && cd lua-resty-core-${LUA_RESTY_CORE_VERSION} \
  && mkdir -p /usr/local/lib/lua/5.1/resty \
  && mkdir -p /usr/local/share/lua/5.1/resty \
  && cp -r lib/* /usr/local/share/lua/5.1/ \
  && cd ../lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION} \
  && cp -r lib/* /usr/local/share/lua/5.1/ \
  && cd .. \
  && rm -rf lua-resty-core-${LUA_RESTY_CORE_VERSION} lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION}

# Download lua-nginx-module
RUN cd /usr/local/src \
  && wget https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_MODULE_VERSION}.tar.gz \
  && tar xzf v${LUA_NGINX_MODULE_VERSION}.tar.gz \
  && rm v${LUA_NGINX_MODULE_VERSION}.tar.gz \
  && mv lua-nginx-module-${LUA_NGINX_MODULE_VERSION} /lua-nginx-module

# Download sources
RUN mkdir ip2location \
  && curl -sS -L https://github.com/chrislim2888/IP2Location-C-Library/archive/refs/tags/${IP2LOCATION_C_VERSION}.tar.gz \
  | tar -C ip2location -xzvf- --strip=1

RUN mkdir ip2proxy \
  && curl -sS -L https://github.com/ip2location/ip2proxy-c/archive/refs/tags/${IP2PROXY_C_VERSION}.tar.gz \
  | tar -C ip2proxy -xzvf- --strip=1

RUN mkdir ip2mod-location \
  && curl -sS -L https://github.com/ip2location/ip2location-nginx/archive/refs/tags/${IP2LOCATION_NGINX_VERSION}.tar.gz \
  | tar -C ip2mod-location -xzvf- --strip=1

RUN mkdir ip2mod-proxy \
  && curl -sS -L https://github.com/ip2location/ip2proxy-nginx/archive/refs/tags/${IP2PROXY_NGINX_VERSION}.tar.gz \
  | tar -C ip2mod-proxy -xzvf- --strip=1

RUN mkdir devmod-detection \
  && curl -sS -L https://github.com/51Degrees/Device-Detection/archive/refs/tags/v${FIFTYONEDEGREES_NGINX_VERSION}.tar.gz \
  | tar -C devmod-detection -xzvf- --strip=1

RUN mkdir cache-purge-module \
  && curl -sS -L https://github.com/nginx-modules/ngx_cache_purge/archive/refs/tags/${NGINX_CACHE_PURGE_VERSION}.tar.gz \
  | tar -C cache-purge-module -xzvf- --strip=1

RUN mkdir nginx-module-vts \
  && curl -sS -L https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v${NGINX_VTS_VERSION}.tar.gz \
  | tar -C nginx-module-vts -xzvf- --strip=1

RUN mkdir nginx \
  && curl -sS -L https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
  | tar -C nginx -xzvf- --strip=1

WORKDIR /nginx

# Compile C Library for IP2Location module
WORKDIR /ip2location
RUN autoreconf -i -v --force
RUN ./configure
RUN make
RUN checkinstall \
  -D \
  --install=no \
  --default \
  --pkgname=ip2location-c \
  --pkgversion=${IP2LOCATION_C_VERSION} \
  --pkgarch=amd64 \
  --pkggroup=lib \
  --pkgsource="https://github.com/chrislim2888/IP2Location-C-Library" \
  --maintainer="Eduard Generalov <eduard@generalov.net>" \
  --requires=librtmp1 \
  --autodoinst=no \
  --deldoc=yes \
  --deldesc=yes \
  --delspec=yes \
  --backup=no \
  make install

WORKDIR /ip2location/data
RUN perl ip-country.pl

WORKDIR /ip2location/test
RUN ./test-IP2Location

# Compile C Library for IP2Proxy module
WORKDIR /ip2proxy
RUN autoreconf -i -v --force
RUN ./configure
RUN make
RUN checkinstall \
  -D \
  --install=no \
  --default \
  --pkgname=ip2proxy-c \
  --pkgversion=${IP2PROXY_C_VERSION} \
  --pkgarch=amd64 \
  --pkggroup=lib \
  --pkgsource="https://github.com/ip2location/ip2proxy-c" \
  --maintainer="Eduard Generalov <eduard@generalov.net>" \
  --requires=librtmp1 \
  --autodoinst=no \
  --deldoc=yes \
  --deldesc=yes \
  --delspec=yes \
  --backup=no \
  make install

# Compile module 51Degress
WORKDIR /devmod-detection
RUN sed -i '/^#define EXTERNAL$/ s/$/ extern/' src/pattern/51Degrees.h
RUN wget -O- https://github.com/gmm42/Device-Detection/commit/dab944b5837e0a38491878b79dbc7b9120e03cc0.diff | patch -p1
RUN cd nginx \
  && make install trie VERSION=$NGINX_VERSION
RUN cd nginx \
  && bash test.sh

# Compile Nginx
WORKDIR /nginx
RUN ./configure \
  --with-compat \
  --prefix=/usr/share/nginx \
  --sbin-path=/usr/bin/nginx \
  --with-http_ssl_module \
  --conf-path=/etc/nginx/nginx.conf \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --modules-path=/usr/lib/nginx/modules \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  --with-http_realip_module \
  --with-http_stub_status_module \
  --with-stream \
  --add-module=../nginx-module-vts \
  --add-module=../cache-purge-module \
  --add-dynamic-module=../ip2mod-proxy \
  --add-dynamic-module=../ip2mod-location \
  --add-dynamic-module=../devmod-detection/nginx/51Degrees_module \
  --add-dynamic-module=../lua-nginx-module \
  --with-cc-opt="-DFIFTYONEDEGREES_TRIE -DFIFTYONEDEGREES_NO_THREADING -fcommon" \
  --with-ld-opt="-Wl,-rpath,/usr/local/lib -L/usr/local/lib -lluajit-5.1" \
  --with-compat

RUN make modules
RUN make -j 8
RUN checkinstall \
  -D \
  --install=no \
  --default \
  --pkgname=nginx \
  --pkgversion=$VERS \
  --pkgarch=amd64 \
  --pkggroup=web \
  --pkgsource="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
  --maintainer="Eduard Generalov <eduard@generalov.net>" \
  --provides=nginx \
  --requires=ip2location-c,ip2proxy-c,libssl3,libc-bin,libc6,libzstd1,libpcre++0v5,libpcre16-3,libpcre2-8-0,libpcre3,libpcre32-3,libpcrecpp0v5,libmaxminddb0 \
  --autodoinst=no \
  --deldoc=yes \
  --deldesc=yes \
  --delspec=yes \
  --backup=no \
  make install

RUN mkdir /packages \
  && mv /*/*.deb /packages/

FROM ubuntu:22.04
COPY --from=stage /packages /packages
COPY --from=stage /usr/local/lib/libluajit* /usr/local/lib/
COPY --from=stage /usr/local/lib/pkgconfig/luajit.pc /usr/local/lib/pkgconfig/
COPY --from=stage /usr/local/include/luajit-2.1 /usr/local/include/luajit-2.1
COPY --from=stage /usr/local/bin/luajit* /usr/local/bin/
COPY --from=stage /usr/local/lib/lua /usr/local/lib/lua
COPY --from=stage /usr/local/share/lua /usr/local/share/lua
COPY nginx-reloader.sh /usr/bin/nginx-reloader.sh

RUN set -x \
  && groupadd --system --gid 101 nginx \
  && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
  && apt update \
  && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates inotify-tools gettext-base \
  && apt -y install /packages/*.deb \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /var/lib/nginx /var/log/nginx \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && chown -R nginx: /var/lib/nginx /var/log/nginx \
  && echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf \
  && ldconfig

ENTRYPOINT ["/usr/bin/nginx", "-g", "daemon off;"]
