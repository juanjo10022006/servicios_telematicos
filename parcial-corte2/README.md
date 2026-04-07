PARCIAL 2
--------------------------------------------------

Estudiante: Juan José Solarte Pabón

Asignatura: Servicios Telematicos

--------------------------------------------------
DESCRIPCIÓN
--------------------------------------------------

Este repositorio contiene el desarrollo del segundo parcial de la asignatura Servicios Telemáticos.

Se implementa una arquitectura basada en tres máquinas virtuales utilizando Vagrant:

- Cliente
- Servidor 1 (Firewall con UFW)
- Servidor 2 (FTPS y SFTP)

Se configuran servicios de transferencia segura de archivos (FTPS y SFTP) protegidos por firewall, así como resolución de nombres mediante DNS over TLS (DoT).

--------------------------------------------------
TECNOLOGÍAS UTILIZADAS
--------------------------------------------------

- Linux Ubuntu 22.04
- Vagrant
- VirtualBox
- vsftpd (FTPS)
- OpenSSH (SFTP)
- UFW (Firewall)
- OpenSSL (Certificados TLS)
- systemd-resolved (DNS over TLS)
- Bash

--------------------------------------------------
ESTRUCTURA DEL PROYECTO
--------------------------------------------------

    ├─ Vagrantfile
    └─ provision/
        ├─ cliente.sh
        ├─ servidor1.sh
        └─ servidor2.sh

--------------------------------------------------
TOPOLOGÍA DE RED
--------------------------------------------------

CLIENTE (192.168.50.10)
        ↓
SERVIDOR 1 - FIREWALL (192.168.50.3)
        ↓ (NAT / DNAT)
SERVIDOR 2 - SERVICIOS (192.168.50.2)

--------------------------------------------------
LEVANTAR MÁQUINAS VIRTUALES
--------------------------------------------------

vagrant up

--------------------------------------------------
PROVISIONAR MÁQUINAS
--------------------------------------------------

vagrant provision

Para reprovisionar una máquina específica:

vagrant provision servidor1
vagrant provision servidor2
vagrant provision cliente

--------------------------------------------------
SERVICIOS IMPLEMENTADOS
--------------------------------------------------

1. FTPS (vsftpd)
- Canal de control: puerto 21
- Puertos pasivos: 50000 - 50010
- Cifrado TLS con certificados generados mediante OpenSSL

2. Firewall UFW
- Política por defecto: deny incoming
- Puertos permitidos:
  - 21 (FTPS)
  - 22 (SFTP)
  - 50000-50010 (FTPS pasivo)
- Implementación de NAT mediante before.rules

3. DNS over TLS (DoT)
- Configurado en cliente mediante systemd-resolved
- Servidores DNS:
  - 1.1.1.1
  - 8.8.8.8
- Tráfico cifrado en puerto 853

4. SFTP (OpenSSH)
- Servicio basado en SSH (puerto 22)
- Transferencia segura de archivos
- Autenticación mediante usuario ftpuser

--------------------------------------------------
PRUEBAS REALIZADAS
--------------------------------------------------

- Verificación de bloqueo de puertos mediante UFW
- Conexión FTPS desde cliente usando FileZilla
- Transferencia de archivos (upload y download)
- Validación de certificado TLS con OpenSSL
- Captura de tráfico con Wireshark (puertos 21, 50000-50010 y 22)
- Configuración y prueba de DNS over TLS (puerto 853)
- Prueba de SFTP:
  - fallo con puerto 22 bloqueado
  - éxito con puerto 22 habilitado

--------------------------------------------------
USUARIO DE PRUEBA
--------------------------------------------------

Usuario: ftpuser  
Contraseña: 123456  

--------------------------------------------------
COMANDOS ÚTILES
--------------------------------------------------

Acceso a máquinas:

vagrant ssh cliente
vagrant ssh servidor1
vagrant ssh servidor2

Prueba SFTP:

sftp ftpuser@192.168.50.3

Prueba FTPS:

Usar FileZilla con:
- Host: 192.168.50.3
- Puerto: 21
- Cifrado: TLS explícito

--------------------------------------------------
OBSERVACIONES
--------------------------------------------------

- El tráfico FTPS y SFTP se encuentra cifrado, lo cual impide visualizar credenciales o contenido en Wireshark.
- La configuración de NAT en el servidor1 es esencial para el funcionamiento de los servicios.
- DNS over TLS protege la privacidad de las consultas DNS mediante cifrado.

--------------------------------------------------