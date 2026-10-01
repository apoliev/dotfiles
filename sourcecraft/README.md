# sourcecraft

Модели SourceCraft в [opencode](https://opencode.ai) через локальный прокси.
Провайдер-конфиг `.config/opencode/opencode.jsonc` ставится stow'ом, этот каталог — нет.

## Как это работает

- `src ipc` поднимает OpenAI-совместимый прокси на `127.0.0.1:8787`; запросы он
  подписывает кредами вашего аккаунта (IAM/DPoP из keyring или файла)
- opencode ходит в него как в провайдеры `sourcecraft` и `sourcecraft-external`
- доступ к прокси — по Bearer-ключу из `~/.config/sourcecraft-ipc/key`
  (генерируется при установке, в git не попадает; opencode читает его из
  переменной `SOURCECRAFT_IPC_API_KEY`, которую экспортирует `.zshrc`)

Модели: `sourcecraft/default`, `sourcecraft/deepseek-v4-flash`,
`sourcecraft/glm-5.2`, `sourcecraft/qwen3.6-35b`,
`sourcecraft-external/glm-5.3`, `sourcecraft-external/glm-5.3-flash`
(у каждой есть variants: `-high`, `-low`, `-none` / `-max`).

## zsh

PATH для `src`, автодополнение и экспорт ключа делает omz-плагин
`sourcecraft` (`zsh/custom/plugins/sourcecraft`), включённый в `plugins=(...)`
в `~/.zshrc`. Пока src CLI не установлен, плагин ничего не делает.
Ключ для opencode экспортируется в `SOURCECRAFT_IPC_API_KEY`; без плагина
его можно выставить вручную:
`export SOURCECRAFT_IPC_API_KEY="$(cat ~/.config/sourcecraft-ipc/key)"`.

## Установка

1. opencode ставится через mise (уже в `.config/mise/config.toml`)
2. `bash ~/.dotfiles/sourcecraft/install.sh` — поставит src CLI (если его нет,
   скачает официальный инсталлер), создаст ключ и systemd-юнит `sourcecraft-ipc`
3. Если ещё не залогинены: `src auth login`
4. Проверка: `opencode run -m sourcecraft/default "Reply with exactly: OK"`

Повторный запуск `install.sh` безопасен: обновляет src до свежего stable
(инсталлер ставит поверх), пересобирает юнит, перезапускает сервис.

Без systemd (старый WSL и т.п.): `bash ~/.dotfiles/sourcecraft/sc-ipc start`.

## WSL2

- включить systemd: в `/etc/wsl.conf` добавить
  ```ini
  [boot]
  systemd=true
  ```
  и выполнить `wsl --shutdown` в PowerShell
- если нет gnome-keyring: в `~/.config/sourcecraft/config.yaml` поставить
  `cred_storage: file` (креды будут лежать в `~/.config/sourcecraft/credentials/`)
- `src auth login` открывает браузер; в WSL2 скопируйте URL в браузер Windows
  вручную — callback на `127.0.0.1` работает через localhost forwarding
- прокси слушает только `127.0.0.1` — наружу не торчит

## Troubleshooting

- `401` от прокси — расхождение ключа: `systemctl --user restart sourcecraft-ipc`
- после `src auth login` (релогин) перезапустить сервис
- логи: `journalctl --user -u sourcecraft-ipc -f` или `sc-ipc logs`
- квота/нейрокредиты: `src quota`
- opencode ругается на провайдера — проверьте, что `SOURCECRAFT_IPC_API_KEY`
  выставлен в окружении (включите zsh-плагин `sourcecraft` или экспортируйте
  ключ вручную)
