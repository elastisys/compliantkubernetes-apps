const PROMETHEUS_URL =
  'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services' +
  '/kube-prometheus-stack-prometheus:9090/proxy'
const DROP_QUERY = 'round(increase(no_policy_drop_counter[15m]))'
const ACCEPT_QUERY = 'sum by (type) (round(increase(policy_accept_counter[15m])))'

describe('workload cluster network policies', function () {
  before(function () {
    cy.visitProxiedWC(PROMETHEUS_URL)
    cy.request('GET', `${PROMETHEUS_URL}/api/v1/status/runtimeinfo`)
      .then(assertServerTime)
      .as('serverTime')
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL(DROP_QUERY, this.serverTime)).then((res) => {
      assertNoDrops(res, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL(DROP_QUERY, this.serverTime)).then((res) => {
      assertNoDrops(res, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.request('GET', makeQueryURL(ACCEPT_QUERY, this.serverTime)).then(assertAccepts)
  })

  after(() => {
    cy.cleanupProxy('wc')
  })
})

describe('service cluster network policies', function () {
  before(function () {
    cy.visitProxiedSC(PROMETHEUS_URL)
    cy.request('GET', `${PROMETHEUS_URL}/api/v1/status/runtimeinfo`)
      .then(assertServerTime)
      .as('serverTime')
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', makeQueryURL(DROP_QUERY, this.serverTime)).then((res) => {
      assertNoDrops(res, 'fw', 'from')
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', makeQueryURL(DROP_QUERY, this.serverTime)).then((res) => {
      assertNoDrops(res, 'tw', 'to')
    })
  })

  it('are accepting allowed traffic', function () {
    cy.request('GET', makeQueryURL(ACCEPT_QUERY, this.serverTime)).then(assertAccepts)
  })

  after(() => {
    cy.cleanupProxy('sc')
  })
})

const assertServerTime = (res) => {
  expect(res.status).to.eq(200)

  const runtimeInfo = res.body
  expect(runtimeInfo.status).to.eq('success')
  expect(runtimeInfo.data.serverTime).to.be.a('string')

  return runtimeInfo.data.serverTime
}

const makeQueryURL = (query, serverTime) => {
  const metric = encodeURI(query)
  return `${PROMETHEUS_URL}/api/v1/query?query=${metric}&${new URLSearchParams({ time: serverTime })}`
}

const assertNoDrops = (res, metricType, direction) => {
  expect(res.status).to.eq(200)
  expect(res.body.data.result).to.be.a('array')

  const result = res.body.data.result

  const drops = result.filter(filterNonZero(metricType)).map(mapDrops)

  if (drops.length > 0) {
    cy.fail(formatError(drops, direction))
  }
}

const assertAccepts = (res) => {
  expect(res.status).to.eq(200)
  expect(res.body.data.result).to.be.a('array')

  const result = res.body.data.result

  const innerAssert = (values) => {
    cy.wrap(values)
      .should('be.an', 'array')
      .its('[0]')
      .should('be.a', 'number')
      .should('be.greaterThan', 0)
  }

  const fwAccept = result.filter(filterNonZero('fw')).map((item) => parseInt(item.value[1]))
  innerAssert(fwAccept)

  const twAccept = result.filter(filterNonZero('tw')).map((item) => parseInt(item.value[1]))
  innerAssert(twAccept)
}

const filterNonZero = (metricType) => {
  return (item) => item.metric.type === metricType && item.value && item.value[1] !== '0'
}

const mapDrops = (item) => {
  return {
    podName: item.metric.exported_pod,
    podNamespace: item.metric.pod_namespace,
    drops: parseInt(item.value[1]),
  }
}

const formatError = (drops, direction) => {
  const fmtDrops = drops
    .map((item) => `- ${item.podNamespace}/${item.podName} had ${item.drops} dropped packets`)
    .join('\n')
  return `\nFound packets dropped ${direction} workloads:\n${fmtDrops}\n`
}
