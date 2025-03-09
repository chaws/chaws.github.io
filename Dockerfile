FROM ruby

COPY ../Gemfile /Gemfile

EXPOSE 4000

RUN bundle 
