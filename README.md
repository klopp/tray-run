# tray-run.pl
Вешается в трей. 

При правом клике по иконке завершается.

При левом - запускает или завершает указанную программу.

# Конфиг

Либо дефолтный (см. `Things::Config::Std`), либо читается из `$ARGV[0]`.

```ini
; что запускать:
Exec    ~/bin/netcam-motion/netcam-motion.pl
; иконка "программа запущена"
On      i/6-on.png
; иконка "программа не запущена"
Off     i/6-off.png
; запускать программу при старте или нет
Active  1
; каким сигналом убивать
Kill    TERM

```

# tray-run-pp.pl

То же самое, но только со стандартными модулями CPAN (без `Things::`).
