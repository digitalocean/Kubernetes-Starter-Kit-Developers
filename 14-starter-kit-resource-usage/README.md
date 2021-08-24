## Cost analysis for your DOKS cluster<a name="COST"></a>

In this part, we’ll focus on introductory CPU monitoring by using simple method, Grafana has some custom dashboards for these purposes.  the size of `Overall CPU Utilisation`,`RAM Utilisation`, `Network IO`, `Disk IO`, `Pod cost` and `utilisation analysis`.These are all key elements that affect the performance of your infrastructure. In grafana, you can use  `6876` or `6873` or `6879` number of dashboard in 'http://localhost:3000/dashboard/import'. Please use `Analysis by Cluster`(1) and `Analysis by Namespace`(2) Refer to these dashboards.

![Dashboard-Cost-CPU-Monitoring](../images/monitoring_cpu_ram_cost.png) (1)
![Dashboard-Cost-CPU-Monitoring-Graph](../images/monitoring_cpu_ram_cost_charts.png)(2)


As we already have the Grafana installed, we can review the dashboards (go to dashboards -> manage) to look at the cpu/memory utilized by each of the namespaces (velero, ambassador, prometheus/loki/grafana). 
Refer to these dashboards.For our starter kit, we're using  `CPU : 1`, and `RAM : 2` as memory. 

For a ballpark sizing, say you're using a node pool for 2 nodes, 4cpu/8gb each. This is about $96/month for the cluster. You will have 6cpu/8gb RAM remaining for use after DOKS installation. If you install the starter kit, then you will have 1cpu/2gb RAM for your node pool with 2 nodes and 9cpu/14gb remaining for your applications.