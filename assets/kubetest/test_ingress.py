"""An example of using kubetest to manage an ingress."""

import os


def test_ingress(kube):

    f = os.path.join(
        os.path.dirname(os.path.realpath(__file__)), "configs", "ingress.yaml"
    )

    ing = kube.load_ingress(f)

    kube.create(ing)

    ing.wait_until_ready(timeout=20)
    ing.refresh()

    ings = kube.get_ingresses()
    assert len(ings) == 1

    kube.delete(ing)

    ing.wait_until_deleted(timeout=20)