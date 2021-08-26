## Cost analysis for your DOKS cluster<a name="COST"></a>

In this part, we’ll focus on introductory CPU monitoring by using simple method, Grafana has some custom dashboards for these purposes. When you click `Manage`, you will see that `Kubernetes/Compute Resources/Cluster` section with `kubernetes-mixin` tag. 


 The size of `CPU Utilisation`,`CPU Requests Commitment`, `CPU Limits Commitment`, `Memory Utilisation`, `Memory Requests Commitment` and `Memory Limits Commitment` are included in headlines. Besides that, when you scroll down your page, you can see that more tables such as `Cpu Usage`, `Memory Usage`,`Network Usage`,`Request by Namespace` and `Bandwidths`

![Dashboard-Cost-CPU-Monitoring-Cluster](../images/monitoring_cpu_ram_cluster.png)

As we already have the Grafana installed, you can review the dashboards (go to dashboards -> manage) to look at `Kubernetes/Compute Resources/Cluster` the cpu/memory utilized by each of the namespaces (velero, ambassador, prometheus/loki/grafana) will be shown in this part.But if you want, you can change queries by clicking `Edit` button both charts and tables .
