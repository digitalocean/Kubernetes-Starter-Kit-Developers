import pytest


@pytest.mark.applymanifests('configs', files=['nginx-ingress.yaml'])
def test_nginx(kube):
    """An example test against an Nginx deployment."""

    # wait for the manifests loaded by the 'applymanifests' marker
    # to be ready on the cluster
    kube.wait_for_registered(timeout=30)

    deployments = kube.get_deployments()
    nginx_deploy = deployments.get('echo-deployment')
    assert nginx_deploy.is_ready() is True

    pods = nginx_deploy.get_pods()
    assert len(pods) == 3, 'nginx should deploy with three replicas'

    for pod in pods:
        containers = pod.get_containers()
        assert len(containers) == 1, 'nginx pod should have one container'

        resp = pod.http_proxy_get('/')
        assert 200 == resp.status

    services = kube.get_services()
    echo_service = services.get('echo-service')

    assert echo_service.is_ready() is True

    ingress = kube.get_ingresses()
    nginx_ingress = ingress.get('echo-ingress')

    assert nginx_ingress.is_ready() is True


