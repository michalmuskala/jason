# Changelog

## 1.0.0 (26.01.2018)

No changes

## 1.0.0-rc.3 (26.01.2018)

### Changes

* update `escape` option of `Jason.encode/2` to take values:
  `:json | :unicode_safe | :html_safe | :javascript_safe` for consistency. Old values of
  `:unicode` and `:javascript` are still supported for compatibility with Poison.
  ([f42dcbd](https://github.com/michalmuskala/jason/commit/f42dcbd))

## 1.0.0-rc.2 (07.01.2018)

### Bug fixes

* add type for `strings` option ([b459ee4](https://github.com/michalmuskala/jason/commit/b459ee4))
* support iodata in `decode!` ([a1f3456](https://github.com/michalmuskala/jason/commit/a1f3456))

## 1.0.0-rc.1 (22.12.2017)

Initial release
