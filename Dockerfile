FROM ruby:3.3.0-slim

# Install system dependencies (postgresql-client, build-essential, libpq-dev)
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev postgresql-client curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Copy and grant execution permissions for docker-entrypoint
COPY bin/docker-entrypoint /rails/bin/docker-entrypoint
RUN chmod +x /rails/bin/docker-entrypoint

EXPOSE 3000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
