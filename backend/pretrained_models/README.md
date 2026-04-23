This directory intentionally stays inside the repository for deploy targets like Heroku.

Local and GPU environments may populate `pretrained_models/` with downloaded model artifacts,
but deploy targets must not use an absolute symlink here because Heroku rejects symlinks that
point outside the app working directory.
