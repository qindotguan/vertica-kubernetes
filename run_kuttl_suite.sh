#!/bin/bash
TEST_SUITE=$1
if [ "x$TEST_SUITE" == "x" ];then
  TEST_SUITE=collect-scrutinize
fi

# clean up
VDB=v-collect-scrutinize
VDB_NS=$(kubectl get vdb --all-namespaces | grep $VDB | awk '{print $1}')
for ns in $VDB_NS; do
  kubectl delete vdb $VDB -n $ns
done
VSCR=vertica-scrutinize
VSCR_NS=$(kubectl get vscr --all-namespaces | grep $VSCR | awk '{print $1}')
for ns in $VDB_NS; do
  kubectl delete vscr $VSCR -n $ns
  kubectl delete vscr ${VSCR}-vdb-exist -n $ns
done
kubectl delete crd verticaautoscalers.vertica.com verticadbs.vertica.com verticareplicators.vertica.com verticarestorepointsqueries.vertica.com verticascrutinizers.vertica.com

# build and push
export VERTICA_DEPLOYMENT_METHOD=vclusterops
make generate manifests
make docker-build-operator docker-push-operator

# run
make init-e2e-env && kubectl kuttl test --test $TEST_SUITE --skip-delete


# check cmds in vscr init pod
VSCR_NS=$(kubectl get vdb --all-namespaces | grep $VDB | awk '{print $1}')
if [ ! -z $VSCR_NS ]; then
  kubectl describe vscr ${VSCR}-vdb-exist -n $VSCR_NS
  kubectl describe pod ${VSCR}-vdb-exist -n $VSCR_NS
fi

# check log
export OPERATOR_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -n verticadb-operator)
kubectl logs $OPERATOR_NAME -n verticadb-operator > /tmp/$OPERATOR_NAME.log
cat /tmp/$OPERATOR_NAME.log | grep debugging
