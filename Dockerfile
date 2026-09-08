FROM verdaccio/verdaccio:5.33.0

USER root
# Store plugin: packages live on hanzoai/s3 (s3.hanzo.svc), zero local disk.
RUN npm install --prefix /verdaccio/plugins verdaccio-aws-s3-storage@10.3.3 \
 && chown -R $VERDACCIO_USER_UID:root /verdaccio/plugins

COPY conf/config.yaml /verdaccio/conf/config.yaml

# config.yaml names both marks by absolute path, so they need a home that is
# stable across a verdaccio bump. Not the theme's static dir: nothing reads the
# mark from there, and the tab icon is answered before that dir is consulted.
COPY web/ /verdaccio/web/

USER $VERDACCIO_USER_UID

EXPOSE 4873

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:4873/-/ping || exit 1
