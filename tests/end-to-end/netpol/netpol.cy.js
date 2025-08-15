const DROP_QUERY = 'round(increase(no_policy_drop_counter[15m]))'
const ACCEPT_QUERY = 'sum by (type) (round(increase(policy_accept_counter[15m])))'

const makePrometheusURL = (proxyPort) =>
  `http://127.0.0.1:${proxyPort}/api/v1/namespaces/monitoring/services` +
  '/kube-prometheus-stack-prometheus:9090/proxy'

describe('workload cluster network policies', function () {
  before(function () {
    cy.request('GET', `${makePrometheusURL(18002)}/api/v1/status/runtimeinfo`)
      .then(assertServerTime)
      .as('serverTime')
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL(18002, DROP_QUERY, this.serverTime)).then((response) => {
      assertNoDrops(response, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL(18002, DROP_QUERY, this.serverTime)).then((response) => {
      assertNoDrops(response, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.request('GET', makeQueryURL(18002, ACCEPT_QUERY, this.serverTime)).then(assertAccepts)
  })
})

describe('service cluster network policies', function () {
  before(function () {
    cy.request('GET', `${makePrometheusURL(18001)}/api/v1/status/runtimeinfo`)
      .then(assertServerTime)
      .as('serverTime')
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL(18001, DROP_QUERY, this.serverTime)).then((response) => {
      assertNoDrops(response, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL(18001, DROP_QUERY, this.serverTime)).then((response) => {
      assertNoDrops(response, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.request('GET', makeQueryURL(18001, ACCEPT_QUERY, this.serverTime)).then(assertAccepts)
  })
})

const assertServerTime = (response) => {
  expect(response.status).to.eq(200)

  const runtimeInfo = response.body
  expect(runtimeInfo.status).to.eq('success')
  expect(runtimeInfo.data.serverTime).to.be.a('string')

  return runtimeInfo.data.serverTime
}

const makeQueryURL = (proxyPort, query, serverTime) => {
  const metric = encodeURI(query)
  return `${makePrometheusURL(proxyPort)}/api/v1/query?query=${metric}&${new URLSearchParams({ time: serverTime })}`
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

const assertAccepts = (response) => {
  expect(response.status).to.eq(200)
  expect(response.body.data.result).to.be.a('array')

  const result = response.body.data.result

  const innerAssert = (values) => {
    cy.wrap(values)
      .should('be.an', 'array')
      .its('[0]')
      .should('be.a', 'number')
      .should('be.greaterThan', 0)
  }

  const fwAccept = result.filter(filterNonZero('fw')).map((item) => Number.parseInt(item.value[1]))
  innerAssert(fwAccept)

  const twAccept = result.filter(filterNonZero('tw')).map((item) => Number.parseInt(item.value[1]))
  innerAssert(twAccept)
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
