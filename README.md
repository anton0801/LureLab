# Lure Lab

Офлайн-дневник испытаний рыболовных приманок с необязательной мастерской (бесплатные капсулы → Lucky Cast 5×3 → Parts → 4 коллекционные приманки). SwiftUI, iOS 15.0+, CLEAN, Core Data, без сети, аккаунтов, рекламы и покупок.

## Запуск

1. Открыть `LureLab.xcodeproj` в Xcode 16+.
2. Схема **LureLab** → любой iPhone-симулятор → Run.
3. Тесты: Product → Test (⌘U) — юнит/интеграционные (`LureLabTests`) и сквозные UI-тесты (`LureLabUITests`).

Из терминала:

```bash
xcodebuild -project LureLab.xcodeproj -scheme LureLab -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Для устройства/App Store выберите свою команду в Signing & Capabilities (bundle id `com.lablure.ss.LureLab`).

## Структура

- `LureLab/Domain` — сущности, правила (капсулы, Lucky Cast, ставки сравнения, валидация, единицы, проверка бэкапа), протоколы репозиториев, use cases. Без SwiftUI.
- `LureLab/Data` — Core Data (программная модель, одна транзакция на операцию), файлы фото в Application Support с file protection, ZIP-бэкап/CSV.
- `LureLab/Presentation` — тема (цвета, Avenir Next как в макетах), компоненты, навигация (собственный стек на каждую вкладку), экраны.
- `LureLab/Assets.xcassets` — ассеты из `integration/Assets.xcassets` пакета дизайна (ID сохранены) + I01 для экрана About.
- `LureLab/Resources/workshop_rules.json` — правила мастерской из пакета; приложение читает их при запуске.
- `QA/` — скриншоты всех 46 состояний и сравнение «макет | приложение».

## Отладочные сценарии (только Debug)

`LURELAB_SCENARIO=<номер экрана 01…46>` открывает нужный экран на in-memory базе с фикстурами из макетов (реальная база не затрагивается; в Release-сборку код не попадает). Пример:

```bash
SIMCTL_CHILD_LURELAB_SCENARIO=20 xcrun simctl launch booted com.lablure.ss.LureLab
```
