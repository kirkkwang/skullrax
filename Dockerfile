FROM ghcr.io/samvera/hyrax-dev:8312a50ce3014031fbd746ab06413fdaa8bd9224

COPY . /skullrax

RUN echo "gem 'skullrax', path: '/skullrax'" >> Gemfile && \
    bundle install

ENV DATABASE_URL=postgresql://dummy:dummy@localhost/dummy

RUN bundle exec rails generate skullrax:install
RUN bundle exec rails assets:precompile
