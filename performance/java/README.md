# JSON Processor

```bash
kubectl logs -l k6_cr=json-processor-load -f --max-log-requests 14
```

```bash
kubectl aperf \
  --aperf_image="christianhxc/aperf:latest" \
  --node="$(kubectl get pod -l app=json-processor -o jsonpath='{.items[0].spec.nodeName}')" \
  --aperf_options="-p 90 --profile --profile-java" \
  --report-name="json-processor"
```