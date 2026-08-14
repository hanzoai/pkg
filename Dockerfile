FROM verdaccio/verdaccio:5.33.0

USER root
# Store plugin: packages live on hanzoai/s3 (s3.hanzo.svc), zero local disk.
RUN npm install --prefix /verdaccio/plugins verdaccio-aws-s3-storage@10.3.3 \
 && chown -R $VERDACCIO_USER_UID:root /verdaccio/plugins

COPY conf/config.yaml /verdaccio/conf/config.yaml

# The UI reads its assets from the theme's static dir, which is what /-/static/
# serves. web.logo takes a basename and resolves to that URL, so the mark has to
# be a file here. The tab icon has no config at all — the rendered <link rel=icon>
# names static/favicon.ico literally — so favicon.ico is replaced, not pointed at.
COPY web/hanzo-mark.svg web/favicon.ico \
  /usr/local/lib/node_modules/verdaccio/node_modules/@verdaccio/ui-theme/static/

USER $VERDACCIO_USER_UID

EXPOSE 4873

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:4873/-/ping || exit 1
