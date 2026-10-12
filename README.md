# Лабораторная: Docker Compose, KVM и Ansible

Небольшое приложение из двух сервисов. Фронтенд (nginx) отдаёт страницу, а она запрашивает
данные у бэкенда (Flask + gunicorn). Сначала всё запускается через Docker Compose, потом
разворачивается внутри виртуальной машины KVM с помощью Ansible. Делалось на 10 баллов + бонусный балл (Trivy).

## Схема

```
Ноутбук (Windows, браузер)
   │  http://localhost:8080  (SSH-туннель)
   ▼
WSL2 Ubuntu 24.04 — хост KVM/libvirt, отсюда же запускается Ansible
   │  SSH, сеть libvirt 192.168.122.0/24
   ▼
VM labvm (Ubuntu 24.04, KVM)
   │  порт 8080
   ▼
Docker Compose:  frontend (nginx :80) ──/api/──►  backend (Flask :8000)
```

Сеть VM находится внутри WSL и с Windows напрямую не видна. Поэтому с ноутбука приложение
открывается через SSH-туннель до порта 8080 виртуальной машины.

## Адрес приложения

http://localhost:8080

## Команды запуска

```bash
# 1. Только Compose (без VM)
docker compose up -d --build

# 2. Создать VM в KVM
./scripts/create-vm.sh

# 3. Развернуть приложение в VM через Ansible
cd ansible
ansible lab -m ping
ansible-playbook playbook.yml

# 4. Туннель, чтобы открыть приложение с ноутбука (отдельный терминал)
VM_IP=$(sudo virsh domifaddr labvm | awk '/ipv4/ {print $4}' | cut -d/ -f1)
ssh -N -L 8080:localhost:8080 -i ~/.ssh/lab_key ubuntu@$VM_IP
```

## Как проверить связь фронтенда с бэкендом

```bash
curl http://localhost:8080/api/hello
```

Придёт JSON с полями `message`, `hostname` (id контейнера бэкенда) и `time`.
Фронтенд сам проксирует `/api/` на бэкенд по имени сервиса из Compose, поэтому порт бэкенда
наружу не публикуется. На странице при открытии сразу выполняется этот запрос, статус
«Бэкенд отвечает» и id контейнера показывают, что связь работает.

---

## Уровень 5

Оба сервиса запущены, порт фронтенда опубликован, страница открывается с ноутбука,
запрос к бэкенду работает.

<img width="960" height="1013" alt="image" src="https://github.com/user-attachments/assets/18f8fe07-2683-4988-a9fc-9928a354a28e" />

<img width="950" height="138" alt="image" src="https://github.com/user-attachments/assets/33869025-f991-4a6d-9458-6693714010ff" />


## Проверка KVM

KVM работает внутри WSL2 на Windows 11. Проверка:

<img width="645" height="210" alt="image" src="https://github.com/user-attachments/assets/cec30d99-0aa4-46f2-b05a-ffad0fee7729" />


## Уровни 7 и 8

Виртуальная машина создана вручную из облачного образа Ubuntu 24.04. Ключ SSH передаётся
через cloud-init. Все шаги собраны в `scripts/create-vm.sh`, главная команда внутри:

<img width="949" height="800" alt="image" src="https://github.com/user-attachments/assets/46cb0ec6-7c41-4cc5-acb7-5d64f28784b5" />

<img width="698" height="402" alt="image" src="https://github.com/user-attachments/assets/fbbcdc6e-6076-4ef6-b52e-dc9809298411" />

Вход в VM по SSH:

<img width="946" height="466" alt="image" src="https://github.com/user-attachments/assets/7a275ede-675b-44e5-8dfb-2fb857917d35" />


Внутри VM Compose запущен, бэкенд отвечает, а `systemd-detect-virt` и `hostnamectl`
показывают виртуализацию `kvm`:

<img width="953" height="437" alt="image" src="https://github.com/user-attachments/assets/58d312e2-14c9-4480-b691-b142b8eb1895" />


С ноутбука приложение открывается через туннель:

<img width="953" height="226" alt="image" src="https://github.com/user-attachments/assets/a23b901d-8cbb-4106-b9e4-fcd3ddab46dd" />

<img width="958" height="1030" alt="image" src="https://github.com/user-attachments/assets/45854615-13a5-4198-97ab-e1bcb8d791bb" />


## Уровень 9

Ansible подключается к VM по SSH, ставит Docker и Compose-плагин, копирует `backend`,
`frontend` и `compose.yaml` в `/opt/laba1`, запускает Compose и ждёт ответа `/api/hello`.

<img width="955" height="329" alt="image" src="https://github.com/user-attachments/assets/b8fe64bd-bf5f-4bdd-b9ba-529b77a24384" />


Первый запуск playbook на чистой VM (задачи с `changed`, в конце `failed=0`):

<img width="952" height="709" alt="image" src="https://github.com/user-attachments/assets/bd8385c6-c94f-4aea-89fa-42e0b7ee5f8d" />


Приложение открывается после запуска:

<img width="957" height="1049" alt="image" src="https://github.com/user-attachments/assets/8755c106-bd6a-4f4a-bbd3-381fa56a4131" />


## Уровень 10

Playbook запускается сколько угодно раз подряд без ручных исправлений. Повторные запуски
идут без ошибок (`failed=0`), почти все задачи `ok`. `changed=1` относится к сборке Compose
(стоит `build: always`).

второй запуск

<img width="941" height="721" alt="image" src="https://github.com/user-attachments/assets/d30a67ab-2802-459a-9e73-e949159ac709" />


третий запуск

<img width="956" height="717" alt="image" src="https://github.com/user-attachments/assets/46202e71-54c3-4e81-b2a3-92fb91d5f82a" />


После запусков фронтенд и бэкенд работают:

<img width="943" height="153" alt="image" src="https://github.com/user-attachments/assets/653fabec-15cb-4f16-a070-39339b508d50" />

<img width="955" height="1078" alt="image" src="https://github.com/user-attachments/assets/64542443-5250-4d6a-accc-eef970c2857e" />


Проверка с перезагрузкой VM (`virsh reboot`): Ansible снова подключается, playbook
проходит без ошибок, приложение открывается.

<img width="944" height="901" alt="image" src="https://github.com/user-attachments/assets/6c6a2f78-9567-4e61-b1b5-fcfb82f4ce58" />

<img width="958" height="1088" alt="image" src="https://github.com/user-attachments/assets/1b71704d-5ba6-43f1-a658-48f930298594" />


## Бонусное задание

Workflow `.github/workflows/trivy.yml` при каждом push и pull request собирает образы из
`compose.yaml` (`laba1-backend`, `laba1-frontend`) и сканирует их Trivy. Найденные
уязвимости не останавливают workflow (`--exit-code 0`), результат виден в логе шага
«Scan images with Trivy». Trivy запускается из контейнера с зафиксированной версией 0.69.3.

Пример запуска: https://github.com/dvshil/laba1/actions/runs/38238770855

<img width="943" height="947" alt="image" src="https://github.com/user-attachments/assets/0d304ffc-888e-4775-8511-be95f5ac9c27" />


Результат для бэкенда:

<img width="1112" height="701" alt="image" src="https://github.com/user-attachments/assets/c649cb38-7f13-4f5e-8b90-3f707faa1c6d" />


Результат для фронтенда:

<img width="1070" height="430" alt="image" src="https://github.com/user-attachments/assets/087ab7a0-0d60-4585-9249-254bb4054fd7" />

