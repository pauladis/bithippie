FROM postgres:15-alpine

# Install additional tools if needed
RUN apk add --no-cache \
    postgresql-client \
    curl

# Copy any initialization scripts here (optional)
# COPY ./init-scripts/*.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
