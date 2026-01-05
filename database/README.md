`schema_v1.sql`  Estructura base (users, products, loans, categories)

`schema_v2.sql`  Mejoras avanzadas (reservations, notifications, settings, loan_history) Ejecutar DESPUÉS de v1👻

`datos_prueba.sql` Datos de prueba (10 usuarios, 15 productos, 8 préstamos)
Ejecutar DESPUÉS de v1👻
LOS DATOS DE PRUEBA USAN CONTRASEÑAS EN TEXTO PLANO:
'Luis', 'Admin123', 'Juan', etc.

EN PRODUCCIÓN SE DEBE IMPLEMENTAR:
1 password_hash() con PASSWORD_BCRYPT en PHP
2 Migrar contraseñas existentes a hash
3 Prepared statements para prevenir SQL injection

# HERRAMIENTAS Y REPORTES
`reportes.sql` 9 reportes avanzados 
`optimizaciones.sql` Tuning, índices, mantenimiento automático 

# BACKUP Y MANTENIMIENTO
`backup_procedure.sql` Sistema de metadatos y logs de backup NO crea archivos .sql reales
Si te sale error necesitas scripts shell externos.
Para backups reales necesitas:
1 Scripts shell (.sh) con mysqldump
2 Cron jobs programados
3 Storage externo (cloud, otro servidor)

# Para backups REALES, necesitas scripts como y más xd:
1. backup_real.sh
!/bin/bash
mysqldump -u usuario -p stocksense_db > backup_$(date +%Y%m%d).sql
gzip backup_$(date +%Y%m%d).sql

2. restore_backup.sh  
!/bin/bash
mysql -u usuario -p stocksense_db < $1

# Ejecutar en ESTE ORDEN:

1. schema_v1.sql
2. datos_prueba.sql  
3. schema_v2.sql
4. consultas_basicas.sql
5. reportes.sql
6. backup_procedure.sql
7. optimizaciones.sql 

# *Nota: Si no funciona nada es porque seria un error de capa 8* 🐣 
