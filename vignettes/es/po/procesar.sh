#/bin/bash
#author: rikivillalba@gmail.com 
#updated 2025-12-02 16:40

pushd $(dirname "$0")

# Crear archivos necesarios
touch catalog.po
touch es.po R-es.po
touch es.po.orig R-es.po.orig
touch es.po.fuzzy R-es.po.fuzzy
touch es.po.untranslated R-es.po.untranslated 

REV_DATE="$(date '+%Y-%m-%d %H:%M%z')"

# TODO: más bucles como éste se pueden utilizar en este programa
for VAR in {"","R-"}es.po{"",".fuzzy",".untranslated"}; do
  echo "comprobando sintaxis de $VAR"
  if ! msgcat $VAR > /dev/null ; then exit 1; fi
done

echo "Nota: es.po.orig y R-es.po.orig son los archivos con la traducción vigente"
echo "es.po y R-es.po serán modificados por el script"
# read -p "¿ Desea copiar los .po actuales a .po.orig [y/n]?" -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]] ; then
echo "copiando [R-]es.po a [R-]es.po.orig"
cp es.po es.po.orig
cp R-es.po R-es.po.orig
# fi

# es.po.fuzzy es generado vía: msgattrib -o es.po.fuzzy --only-fuzzy es.po
# El usuario *debe editar el archivo y eliminar la marca "fuzzy"* donde corresponda.
# Los que no fueron editados y sacados de fuzzy NO SE AGREGAN AL CATALOGO 

echo "obteniendo mensajes corregidos de *.po.fuzzy..."
msgattrib -o es.po.fuzzy --force-po --no-fuzzy es.po.fuzzy
msgattrib -o R-es.po.fuzzy --force-po --no-fuzzy R-es.po.fuzzy

echo "usando SED para borrar el aviso que pusimos al principio de *.po.fuzzy"
sed -i -n -e '/^[^#]/,$p' es.po.fuzzy
sed -i -n -e '/^[^#]/,$p' R-es.po.fuzzy

REPLY=""
echo "¿Desea actualizar el catálogo con el contenido ya traducido en es.po y R-es.po?"
echo "Seleccione SI para dar por bueno el contenido de los .po y ACTUALIZAR el catálogo"
echo "Seleccione NO si quiere actualizar sólo entradas nuevas. Pero las entradas ya"
echo "existentes en el catálogo REEMPLAZARÁN a las que haya en los .po" 
until [[ $REPLY =~ ^[Yn]$ ]] ; do read -p "¿[Y/n]?" -n 1 -r ; echo ; done
if [[ $REPLY == "Y" ]] ; then
  echo "actualizando catalog.po con el contenido actual de es.po y R-es.po" 
  msgcat -o catalog.po --use-first <(msgattrib --translated es.po) catalog.po
  msgcat -o catalog.po --use-first <(msgattrib --translated R-es.po) catalog.po
else 
  echo "agregando a catalog.po sólo las nuevas entradas que se encuentren en .po"
  msgcat -o catalog.po --use-first catalog.po <(msgattrib --translated es.po)
  msgcat -o catalog.po --use-first catalog.po <(msgattrib --translated R-es.po)
fi

# este script se puede ejecutar varias veces. si en ejecución anterior se corrigieron fuzzy
# o se agregaron untranslated, se agregan al catálogo. 
echo "agregando mensajes 'fuzzy' corregidos y nuevos 'unstranslated' a catalog.po..."
msgcat -o catalog.po --use-first es.po.fuzzy es.po.untranslated catalog.po
msgcat -o catalog.po --use-first R-es.po.fuzzy R-es.po.untranslated catalog.po

echo "actualizando *.po a partir del catálogo..."
# Depende de lo que se haya escogido en REPLY 
msgcat -o es.po --more-than=1 --use-first catalog.po es.po
msgcat -o R-es.po --more-than=1 --use-first catalog.po R-es.po

echo "actualizando .po contra la plantilla (.pot)"
msgmerge -U --backup=off -C catalog.po es.po data.table.pot
msgmerge -U --backup=off -C catalog.po R-es.po R-data.table.pot

echo "cambiando fecha de revision..."
sed -i -e "s/^\"PO-Revision-Date: .*/\"PO-Revision-Date: ${REV_DATE}\\\\n\"/" es.po
sed -i -e "s/^\"PO-Revision-Date: .*/\"PO-Revision-Date: ${REV_DATE}\\\\n\"/" R-es.po

echo "generando nuevos *.po.untranslated"
msgattrib -o es.po.untranslated --force-po --untranslated es.po
msgattrib -o R-es.po.untranslated --force-po --untranslated R-es.po

echo "generando nuevos *.po.fuzzy..."
msgattrib -o es.po.fuzzy --force-po --only-fuzzy es.po
msgattrib -o R-es.po.fuzzy --force-po --only-fuzzy R-es.po

echo "agregar nota con aviso en *.po.fuzzy..."
for VAR in {"R-"}"es.po.fuzzy" ; do
  sed -i -e "
     1i # ========================================================================
     1i # Nota: Luego de editar las lineas que considere, elimine la marca 'fuzzy'
     1i # teniendo cuidado de preservar las otras marcas (ej c-format) y la coma
     1i # luego de la almohadilla (#,). Las entradas 'fuzzy' no se incorporan 
     1i # a catalog.po ni al archivo traducido.
     1i # ========================================================================
   " $VAR
done

echo
echo "*** Resumen ***"
echo "==============="
echo

for VAR in {"","R-"}es.po{"",".fuzzy",".untranslated"}; do
  echo "Resultados para ${VAR}:"
  if ! msgfmt -o /dev/null --statistics $VAR ; then exit 1; fi
  if ! msgfmt -o - --check $VAR > /dev/null 2>&1; then 
    echo "* NOTA: algunos chequeos fallaron, ver salida de \`msgfmt -o /dev/null --check $VAR\`" 
  fi
done

echo "Revise los archivos arriba mencionados. No olvide de eliminar \"fuzzy\" de las entradas que actualice."

popd
