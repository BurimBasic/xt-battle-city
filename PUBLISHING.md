# Как опубликовать этот репозиторий на GitHub

Владельцем предполагается **BurimBasic**. Нужен только новый **пустой публичный** репозиторий с именем `xt-battle-city`; не добавляйте к нему автоматически README/License/.gitignore, потому что они уже находятся здесь.

Вариант A — через веб: открыть https://github.com/new , выбрать владельца `BurimBasic`, имя `xt-battle-city`, Visibility = Public, нажать Create repository. Затем в терминале в этой папке:

```sh
git remote add origin https://github.com/BurimBasic/xt-battle-city.git
git push -u origin main
```

Для push нужна обычная авторизация GitHub пользователя (например, Git Credential Manager), пароль учётной записи вместо PAT использовать нельзя.

Вариант B — если установлен и авторизован GitHub CLI `gh`:

```sh
gh repo create BurimBasic/xt-battle-city --public --source=. --remote=origin --push
```

Проверить после push: https://github.com/BurimBasic/xt-battle-city , Actions, файлы `README.md` и `docs/POISK1.md`. Этот архив уже содержит локальный git-commit с веткой main, но пока GitHub не подтвердит создание и push, **публичного репозитория нет**.
