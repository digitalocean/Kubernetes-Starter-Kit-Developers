## Alerting and Notification

### Table of contents

- [Alerting and Notification](#alerting-and-notification)
  - [Table of contents](#table-of-contents)
  - [Overview](#overview)
  - [Creating New Alert and Notification in Prometheus](#creating-new-alert-and-notification-in-prometheus)
    - [Alerting](#alerting)
    - [Notification By Slack](#notification-by-slack)
    - [Notification By Emailing](#notification-by-emailing)
  - [Alerting and Notification Grafana](#alerting-and-notification-grafana)


### Overview

How to create an `alert`?

> we will learn how to configure Prometheus Email alerting with `AlertManager`. AlertManager is used to handle alerts sent by client applications such as the Prometheus server.

What kind of alerts using in `Prometheus Alert Manager` as a default ? 

1. TargetDown
2. Watchdog 
3. KubePodCrashLooping
4. KubePodNotReady
5. KubeDeploymentReplicasMismatch
6. KubeStatefulSetReplicasMismatch 
7. KubeJobCompletion 
8. KubeJobFailed 
9. CPUThrottlingHigh
10. KubeControllerManagerDown
11. KubeSchedulerDown

In this part, we will add new alerts and create a notification as `Slack` and an `Email`.


### Creating New Alert and Notification in Prometheus 

For sending notifications about firing alerts to an external service, Alerting rules allow you to define alert conditions based on Prometheus expression language expressions. Whenever the alert expression results in one or more vector elements at a given point in time, the alert counts as active for these elements' label sets.Because of that we need to change the values file before helming.

Steps to follow:

#### Alerting

Alert config includes 3 important parts in prom-stack-values.yaml. These are `alert`,`expr`,`for`. 

```shell
groups:
- name: example
  rules:
  - alert: <Give a name>
    expr: <Prometheus Query>
    for: <Repeating Time Interval>
    labels:
      severity: page
    annotations:
      summary: <Simple Detail about alert>
``` 
Below command fives to you to see all created and default rules by using Filtering.

``` 
kubectl --namespace monitoring port-forward svc/kube-prom-stack-kube-prome-alertmanager 9093

```
Add rules in part of `additionalPrometheusRules` like that:

```shell
additionalPrometheusRules: 
 - name: my-rule-file
   groups:
   - name: AllInstances
     rules:
     - alert: InstanceDown
       # Condition for alerting
       expr: sum(kube_pod_owner{namespace="ambassador"}) by (namespace) < 5
       for: 1m
       # Annotation - additional informational labels to store more information
       annotations:
         title: 'Instance {{ $labels.instance }} down'
         description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute.'
       # Labels - additional labels to be attached to the alert
       labels:
         severity: 'critical'
     - alert: PrometheusJobMissing
       expr: absent(up{job="prometheus"})
       for: 1m
       labels:
         severity: warning
       annotations:
         summary: Prometheus job missing (instance {{ $labels.instance }})
         description: "A Prometheus job has disappeared\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
     - alert: PrometheusAllTargetsMissing
       expr: count by (job) (up) == 0
       for: 0m
       labels:
         severity: critical
       annotations:
         summary: Prometheus all targets missing (instance {{ $labels.instance }})
         description: "A Prometheus job does not have living target anymore.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
```
Creating above rules helps us to understand our cluster needs and health condition.`additionalPrometheusRules` part enables you to use PromQL to define metric expressions that you can alert on. You define the alert conditions using the PromQL-based metric expression. This way, you can combine different metrics and warn on cases like service-level agreement breach, running out of disk space in a day, and so on.

* `InstanceDown` helps us to catch any replica not running or unhealth pod(s) appear in ambassador namespace. 
* `PrometheusJobMissing` is detecting prometheus job is missing or not alive by using `absent` function.
* `PrometheusAllTargetsMissing` helps to understand Prometheus all target health conditions. 

when you visit  `http://localhost:9093/alerts`, you can see that one of the created rules by yourself when you make filtering.

[AlertManager Filtering](res/img/alertmanager-filtering.png)

#### Notification By Slack

1. Add the `config` part should include `slack_api_url`, `routes` and `slack_config` parts:

  ```
  alertmanager:
  config:
    global:
      resolve_timeout: 5m
      slack_api_url: "https://hooks.slack.com/services/< Token Created By Slack >"
    route:
      group_by: ['job']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      routes:
      - match:
        receiver: 'slack'
        continue: true
    receivers:
    - name: 'slack'
      slack_configs:
      - channel: '#promalerts'
        send_resolved: false
        title: '[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] Monitoring Event Notification'
        text: "test 123"
    ```

2. Apply below upgrading command:

    ```shell
      helm upgrade kube-prom-stack prometheus-community/kube-prometheus-stack --version 17.1.3 --namespace monitoring --create-namespace -f prom-stack-values.yaml
    ```

    **Notes:**
    - slack_api_url : When you decide to send notification by using slack you have to create a channel that gives you a token inside of the url. we prefer here `Incoming WebHooks` for hooking. it's an easiest way  to send a notification. Please visit to create a channel and get your own token from Slack.[Slack messaging](https://api.slack.com/legacy/custom-integrations/messaging/webhooks)
    - routes: in this part you will have some `receivers` and tell `routes` for `match` receiver here.
    - slack_configs: this segment imcludes more than `4` parts but here, `channel`,`title`,`text` are important parts for telling `Slack router` which channel and which title-text message will have. 
    This part totally related with how to use notification in `prom-stack-values.yaml`. Please visit the [Prometheus-Notifications](https://prometheus.io/docs/alerting/latest/notification_examples/) page for more details about this chart.

#### Notification By Emailing

(To be added)

In the next part you will learn `Grafana` to use the `Alerts` for above purposes.

### Alerting and Notification Grafana 

You already have  `Grafana` installed. Now it's time to create some alerts and notification. Ofcourse, we can use some rules from above to understand better. 

Let's add the `Loki` data source to `Grafana`. Go to the `Grafana` web console and follow these steps: 

Creating Notification:
1. Click the `Alert rules` bell from the left panel.
2. Select `Notification channels`.
3. Click the `New channel` top of the panel.
4. Select `Type` from the list and Slack `Slack` using webhook address `https://hooks.slack.com/services/< Token Created By Slack >`. 
5. Test and Save.

Running Notification:
1. Click the `Dashboard` plus from the left panel.
2. Select `Add an empty panel`.
3. Click the `Edit` top of the panel.
4. Add `sum(kube_pod_owner{namespace="ambassador"}) by (namespace) <5`  command when total replicas reduce under 5(ambassador-agent,redis,3 pods), it will throw a notification.
5. Click the `Alert` tab and Click `Create Alert` button inside panel.
6. Add `Condition` part with `WHEN min () OF query (A, 5m, now) IS BELOW 5` as a rule
7. Fill `evaluate every` with 1m  and `For` with 5m parts
8. Choose `promalerts` as `sendto` in Notification part 
9. write `it is a kind of test for starterkit` as a message.
10. Test and Save.

[Grafana Alert and Slack Notify](res/img/alertmanager-grafana-slack.png)


 When defining our alert rules helping you how to connect Grafana to Slack, so that alerts in Grafana create notifications like above picture. For more detail [Please visit Grafana page ,Step-by-step guide to setting up Prometheus Alertmanager with Slack, PagerDuty, and Gmail](https://grafana.com/blog/2020/02/25/step-by-step-guide-to-setting-up-prometheus-alertmanager-with-slack-pagerduty-and-gmail/)
