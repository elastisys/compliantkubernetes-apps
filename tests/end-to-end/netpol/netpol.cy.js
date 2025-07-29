const proxyBaseUrl =
  'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services' +
  '/kube-prometheus-stack-prometheus:9090/proxy'

describe('workload cluster network policies', function () {
  before(function () {
    cy.visitProxiedWC(proxyBaseUrl)
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', `${proxyBaseUrl}/api/v1/status/runtimeinfo`).then((res) => {
      const serverTime = assertServerTime(res)

      cy.request('GET', makeQueryURL(serverTime)).then((res) => {
        assertNoDrops(res, 'fw', 'from')
      })
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', `${proxyBaseUrl}/api/v1/status/runtimeinfo`).then((res) => {
      const serverTime = assertServerTime(res)

      cy.request('GET', makeQueryURL(serverTime)).then((res) => {
        assertNoDrops(res, 'tw', 'to')
      })
    })
  })

  after(() => {
    cy.cleanupProxy('wc')
  })
})

describe('service cluster network policies', function () {
  before(function () {
    cy.visitProxiedSC(proxyBaseUrl)
  })

  it('are not dropping any packets from workloads', function () {
    cy.request('GET', `${proxyBaseUrl}/api/v1/status/runtimeinfo`).then((res) => {
      const serverTime = assertServerTime(res)

      cy.request('GET', makeQueryURL(serverTime)).then((res) => {
        assertNoDrops(res, 'fw', 'from')
      })
    })
  })

  it('are not dropping any packets to workloads', function () {
    cy.request('GET', `${proxyBaseUrl}/api/v1/status/runtimeinfo`).then((res) => {
      const serverTime = assertServerTime(res)

      cy.request('GET', makeQueryURL(serverTime)).then((res) => {
        assertNoDrops(res, 'tw', 'to')
      })
    })
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

const makeQueryURL = (serverTime) => {
  const metric = encodeURI('round(increase(no_policy_drop_counter[15m]))')
  return `${proxyBaseUrl}/api/v1/query?query=${metric}&${new URLSearchParams({ time: serverTime })}`
}

const assertNoDrops = (res, metricType, direction) => {
  expect(res.status).to.eq(200)
  expect(res.body.data.result).to.be.a('array')

  const result = res.body.data.result

  const drops = result.filter(filterDrops(metricType)).map(mapDrops)

  if (drops.length > 0) {
    cy.fail(formatError(drops, direction))
  }
}

const filterDrops = (metricType) => {
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
