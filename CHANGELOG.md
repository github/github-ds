# Changelog

## 0.2.5

Fixes

* Replaces `requires` with `require_relative` to avoid requirement errors
when the gem is required inside the a "gihub" load path https://github.com/github/github-ds/commit/cb50e5318c911cf5bbf30fd07ca8ea93bfbf1c6d

## 0.2.4

Additions

* `GitHub::SQL.transaction` was added to allow `GitHub::SQL` queries to run transactionally https://github.com/github/github-ds/pull/24

## 0.2.3

Additions

* github-ds does not use `blank?` anymore, thus not depending on `active_support/core_ext/object/blank` https://github.com/github/github-ds/commit/a22c397eaaa00bb441fb4a0ecdf3e371daa9001a

Fixes

* `ActiveRecord::Base.default_timezone` is not unintentionally set to `nil` https://github.com/github/github-ds/pull/22

## 0.2.2

Additions

* `GitHub::KV` accepts `SQL::Literal` as valid values https://github.com/github/github-ds/pull/21/commits/c11d4e3154dd3435d509a3356f46d0a2981d7234

Fixes

* Value length validation takes into account that strings can be made of multi-byte characters https://github.com/github/github-ds/pull/21/commits/5156f95ef04b1ecf2ce90929c5752b2e61d39566

## 0.2.1

Additions

* `Result.new` without block returns `true` for `ok?` https://github.com/github/github-ds/pull/19

## 0.2.0

Fixes

* Fixed rails generator name https://github.com/github/github-ds/pull/16
* Add active_record as dependency (not just dev dependency) https://github.com/github/github-ds/commit/e9ce8e4e47d39152021976482e1a0a60efbb9d20

## 0.1.0

* Initial release.
