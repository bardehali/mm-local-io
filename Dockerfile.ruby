# Dockerfile.ruby

# Purpose: Builds a Ruby on Rails app image for mm-local-io
# - Installs system dependencies needed for Rails, MySQL, assets, etc.
# - Sets working directory to /var/www/mm-local-io
# - Copies the full app into the container and installs gems
# - Runs Rails server on port 8000

FROM ruby:2.7.8

# Install dependencies
RUN apt-get update && apt-get install -y \
    nodejs \
    libxml2-dev \
    libxslt-dev \
    yarn \
    libc-dev \
    rsync \
    nginx \
    puma \
    default-mysql-client \
    ca-certificates \
    curl \
    git \
    gnupg \
    imagemagick \
    libffi-dev \
    openssh-client \
    tzdata

# Set environment variables
ENV APP_PATH /var/www/mm-local-io
ENV PORT 8000
ENV RAILS_ENV development
ENV NODE_ENV development

# Create and set working directory
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH

# Copy the entire Rails app
COPY . $APP_PATH

# Install Bundler
RUN gem install bundler -v 2.4.22

# Install gems (excluding production & staging)
RUN bundle install --without production staging

# Expose port 8000
EXPOSE $PORT

# Default command to start the Rails server
CMD ["bundle", "exec", "rails", "server", "-p", "8000", "-b", "0.0.0.0"]
