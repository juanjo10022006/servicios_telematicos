PARCIAL 1
--------------------------------------------------

Estudiante: Juan Jose Solarte Pabon

Asignatura: Servicios Telematicos

--------------------------------------------------
DESCRIPCIÓN
--------------------------------------------------

Este repositorio contiene el desarrollo del parcial


--------------------------------------------------
TECNOLOGÍAS UTILIZADAS
--------------------------------------------------

- Linux Ubuntu 22.04
- Vagrant
- VirtualBox
- Bind9 (DNS)
- Apache2
- Bash

--------------------------------------------------
ESTRUCTURA DEL PROYECTO
--------------------------------------------------

```
├─ Vagrantfile
└─ provision/
    ├─ maestro.sh
    ├─ esclavo.sh
    └─ cliente.sh
```

--------------------------------------------------
LEVANTAR MÁQUINAS VIRTUALES CON VAGRANT
--------------------------------------------------
```bash
vagrant up
```
--------------------------------------------------
PROVISIONAR MAQUINAS VIRTUALES
--------------------------------------------------
```bash
vagrant provision
```
En caso de Error en el provisionamiento de la VM esclavo hacer lo siguiente:
```bash
vagrant ssh maestro
vagrant@~: sudo cat /etc/bind/keys.empresa-transfer.key
```
Copiar la información proporcionada por el comando y pegarla en
```bash
vagrant ssh esclavo
vagrant@~: sudo vim /etc/bind/keys.empresa-transfer.key
```
Por ultimo
```bash
vagrant provision
```
Revisar
```bash
vagrant status
```