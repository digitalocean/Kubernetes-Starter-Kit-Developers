# Overview

In IT and cloud computing, observability is the ability to measure a system’s current state based on the data it generates, such as logs, metrics, and traces.
Observability relies on telemetry derived from instrumentation that comes from the endpoints and services in your multi-cloud computing environments. In these modern environments, every hardware, software, and cloud infrastructure component and every container, open-source tool, and microservice generates records of every activity. The goal of observability is to understand what’s happening across all these environments and among the technologies, so you can detect and resolve issues to keep your systems efficient and reliable.

Observability has become more critical in recent years, as cloud-native environments have gotten more complex and the potential root causes for a failure or anomaly have become more difficult to pinpoint.

Observability allows teams to:

- Monitor modern systems more effectively.
- Find and connect effects in a complex chain and trace them back to their cause.
- Enable visibility for system administrators, IT operations analysts and developers into the entire architecture.

Observability is a measure of how well the system’s internal states can be inferred from knowledge of its external outputs. It uses the data and insights that monitoring produces to provide a holistic understanding of your system, including its health and performance. The observability of your system, then, depends partly on how well your monitoring metrics can interpret your system's performance indicators.

During this chapter you will install and configure the `Prometheus` stack for monitoring your DOKS cluster, `Loki` to fetch and aggregate logs from your cluster's resources and view them in `Grafana` and configure `AlertManager` to alert and notify when there is a critical issue in your cluster.
You will also configure the `events exporter` tool to grab `Kubernetes events` and send and store them in `Loki` as they are a great way to monitor the health and activity of your K8s clusters.

For a complete observability stack, please follow below guides:

- [Prometheus Stack](prometheus-stack.md)
- [Loki](loki-stack.md)
- [Kubernetes Events Exporter](event-exporter.md)
- [Alerts and Notifications](alerts-and-notifications.md)

You will start by installing and configuring the [Prometheus Stack](prometheus-stack.md).
