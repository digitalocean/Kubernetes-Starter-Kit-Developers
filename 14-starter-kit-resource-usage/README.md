## Estimate resources for startup kit 
As we already have the Grafana installed, we can review the dashboards (go to dashboards -> manage) to look at the cpu/memory utilized by each of the namespaces (velero, ambassador, prometheus/loki/grafana). 

Refer to these dashboards.
<TBD>

For our starter kit, we're using <TBD> cpu, and <TBD> memory. 

For a ballpark sizing, say you're using a node pool for 2 nodes, 4cpu/8gb each. This is about $96/month for the cluster. You will have 6cpu/8gb RAM remaining for use after DOKS installation. If you install the starter kit, then you will have <TBD-4cpu/6gb> RAM remaining for your applications.


This is the last section for manual setup of startup kit.
