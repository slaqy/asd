#!/bin/bash

# LIMPIEZA DE REGLAS EN IPTABLES
iptables -F
iptables -X
iptables -Z

# Crear nuevas cadenas para logging
iptables -N LOG_INPUT_ACCEPT
iptables -A LOG_INPUT_ACCEPT -j LOG --log-level 7 --log-prefix "[INPUT_ACCEPT]: "
iptables -A LOG_INPUT_ACCEPT -j ACCEPT

iptables -N LOG_INPUT_DROP
iptables -A LOG_INPUT_DROP -j LOG --log-level 7 --log-prefix "[INPUT_DROP]: "
iptables -A LOG_INPUT_DROP -j DROP

iptables -N LOG_FORWARD_DROP
iptables -A LOG_FORWARD_DROP -j LOG --log-level 7 --log-prefix "[FORWARD_DROP]: "
iptables -A LOG_FORWARD_DROP -j DROP

# POLÍTICAS POR DEFECTO
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permitir tráfico en la interfaz de loopback
iptables -A INPUT -i lo -j LOG_INPUT_ACCEPT

# Permitir tráfico de la intranet
iptables -A INPUT -i enp0s3 -j LOG_INPUT_ACCEPT
iptables -A INPUT -i enp0s9 -j LOG_INPUT_ACCEPT
iptables -A INPUT -i enp0s10 -j LOG_INPUT_ACCEPT

# Permitir tráfico establecido y relacionado
iptables -A INPUT -i enp0s3 -m state --state ESTABLISHED,RELATED -j LOG_INPUT_ACCEPT
iptables -A INPUT -i enp0s8 -m state --state ESTABLISHED,RELATED -j LOG_INPUT_ACCEPT

# Permitir respuestas de ping del host
iptables -A INPUT -i enp0s8 -p icmp --icmp-type echo-reply -j LOG_INPUT_ACCEPT

# Configuración de NAT para dar acceso a Internet a las redes internas
iptables -t nat -A POSTROUTING -s 192.168.21.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.22.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.23.0/24 -o enp0s3 -j MASQUERADE

# Proporcionar la IP de debian1 a todo el tráfico hacia la extranet
iptables -t nat -A POSTROUTING -o enp0s8 -j SNAT --to 192.168.56.2

# Redirección de peticiones al servidor web en debian2 y al servidor ssh en debian5
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 8080 -j DNAT --to 192.168.21.2:80
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 8443 -j DNAT --to 192.168.21.2:443
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 22 -j DNAT --to 192.168.23.1:22

# Permitir tráfico hacia debian5 por el puerto 22 (SSH) y hacia debian2 por los puertos 80 (HTTP) y 443 (HTTPS)
iptables -A FORWARD -d 192.168.23.1 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -d 192.168.21.2 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 192.168.21.2 -p tcp --dport 443 -j ACCEPT

# Permitir todo el tráfico de la intranet
iptables -A FORWARD -i enp0s3 -j ACCEPT
iptables -A FORWARD -i enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s10 -j ACCEPT

# Permitir respuestas de ping del host en la cadena FORWARD
iptables -A FORWARD -i enp0s8 -p icmp --icmp-type echo-reply -j ACCEPT

# Log and drop all other input and forward traffic
iptables -A INPUT -j LOG_INPUT_DROP
iptables -A FORWARD -j LOG_FORWARD_DROP

# Preservación de las reglas de iptables
iptables-save > /etc/iptables/rules.v4

echo "Reglas de iptables configuradas correctamente."

