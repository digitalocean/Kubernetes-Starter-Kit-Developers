
"""An example of using kubetest to manage a deployment."""

import os

import kubernetes.client

def test_deployment(kube):

    f = os.path.join(
        os.path.dirname(os.path.realpath(__file__)), "configs", "deployment.yaml"
    )

    d = kube.load_deployment(f)

    kube.create(d)

    d.wait_until_ready(timeout=20)
    d.refresh()

    pods = d.get_pods()
    assert len(pods) == 1

    p = pods[0]
    p.wait_until_ready(timeout=10)

    # Issue an HTTP GET against the Pod. The deployment
    # is an http echo server, so we should get back data
    # about the request.
    r = p.http_proxy_get(
        "/test/get",
        query_params={"abc": 123},
    )
    get_data = r.json()
    assert get_data["path"] == "/test/get"
    assert get_data["method"] == "GET"
    assert get_data["body"] == ""
    # fixme (etd): I would expect this to be {'abc': 123}, matching
    #   the input data types (e.g. value not a string). Need to determine
    #   where this issue lies..
    #   This may be an issue with the image reflecting the request back.
    assert get_data["query"] == {"abc": "123"}

    # Issue an HTTP POST against the Pod. The deployment
    # is an http echo server, so we should get back data
    # about the request.
    r = p.http_proxy_post(
        "/test/post",
        query_params={"abc": 123},
        data="foobar",
    )
    post_data = r.json()
    assert post_data["path"] == "/test/post"
    assert post_data["method"] == "POST"
    assert post_data["body"] == '"foobar"'
    # fixme (etd): I would expect this to be {'abc': 123}, matching
    #   the input data types (e.g. value not a string). Need to determine
    #   where this issue lies..
    #   This may be an issue with the image reflecting the request back.
    assert post_data["query"] == {"abc": "123"}

    containers = p.get_containers()
    c = containers[0]
    assert len(c.get_logs()) != 0

    kube.delete(d)
    d.wait_until_deleted(timeout=20)