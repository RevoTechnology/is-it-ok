FROM ruby:2.6.5
ENV LANG C.UTF-8
WORKDIR /usr/src/app
RUN gem install bundler:2.1.2
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

CMD ["bundle","exec","thin", "-C", "config/thin.yml","--environment", "$APP_ENV", "-R", "config.ru", "start"]