const DROP_QUERY = 'round(increase(no_policy_drop_counter[15m]))'
const ACCEPT_QUERY = 'sum by (type) (round(increase(policy_accept_counter[15m])))'

function makePrometheusURL(/** @type {Cluster} */ cluster) {
  const port = cluster === 'wc' ? Cypress.env('WC_PROXY_PORT') : Cypress.env('SC_PROXY_PORT')

  return (
    `http://127.0.0.1:${port}/api/v1/namespaces/monitoring/services` +
    '/kube-prometheus-stack-prometheus:9090/proxy'
  )
}

describe('workload cluster network policies', function () {
  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL('wc', DROP_QUERY)).then((response) => {
      assertNoDrops(response, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL('wc', DROP_QUERY)).then((response) => {
      assertNoDrops(response, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.retryRequest({
      request: { method: 'GET', url: makeQueryURL('wc', ACCEPT_QUERY) },
      condition: acceptCondition,
      waitTime: 10000,
      attempts: 30,
    })
  })
})

describe('service cluster network policies', function () {
  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL('sc', DROP_QUERY)).then((response) => {
      assertNoDrops(response, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL('sc', DROP_QUERY)).then((response) => {
      assertNoDrops(response, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.retryRequest({
      request: { method: 'GET', url: makeQueryURL('sc', ACCEPT_QUERY) },
      condition: acceptCondition,
      waitTime: 10000,
      attempts: 30,
    })
  })
})

const makeQueryURL = (/** @type {Cluster} */ cluster, query, serverTime = '') => {
  const metric = encodeURI(query)
  let returnValue = `${makePrometheusURL(cluster)}/api/v1/query?query=${metric}`
  if (serverTime !== '') {
    returnValue = `${returnValue}&${new URLSearchParams({ time: serverTime })}`
  }
  return returnValue
}

const assertNoDrops = (response, metricType, direction) => {
  expect(response.status).to.eq(200)
  expect(response.body.data.result).to.be.a('array')

  const result = response.body.data.result

  const drops = result.filter(filterNonZero(metricType)).map((element) => mapDrops(element))

  if (drops.length > 0) {
    cy.fail(formatError(drops, direction))
  }
}

const acceptCondition = (response) => {
  try {
    expect(response.status).to.eq(200)
    expect(response.body.data.result).to.be.a('array')

    const result = response.body.data.result

    const innerAssert = (values) => {
      expect(values).to.be.an('array')
      expect(values).to.have.property('0').that.is.a('number').and.is.greaterThan(0)
    }

    innerAssert(result.filter(filterNonZero('fw')).map((item) => Number.parseInt(item.value[1])))
    innerAssert(result.filter(filterNonZero('tw')).map((item) => Number.parseInt(item.value[1])))
    return true
  } catch {
    return false
  }
}

const filterNonZero = (metricType) => {
  return (item) => item.metric.type === metricType && item.value && item.value[1] !== '0'
}

const mapDrops = (item) => {
  return {
    podName: item.metric.exported_pod,
    podNamespace: item.metric.pod_namespace,
    drops: Number.parseInt(item.value[1]),
  }
}

const formatError = (drops, direction) => {
  const fmtDrops = drops
    .map((item) => `- ${item.podNamespace}/${item.podName} had ${item.drops} dropped packets`)
    .join('\n')
  return `\nFound packets dropped ${direction} workloads:\n${fmtDrops}\n`
}
