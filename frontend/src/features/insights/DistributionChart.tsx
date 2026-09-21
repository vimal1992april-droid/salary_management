import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import type { Distribution } from '../../api/insights'
import { formatNumber, formatUsd } from '../../lib/format'

const thousands = (amount: string) => `$${Math.round(Number(amount) / 1000)}k`

/** The histogram. It is decoration on top of the data table beside it, so it is hidden from assistive technology. */
export default function DistributionChart({ buckets }: { buckets: Distribution['buckets'] }) {
  const data = buckets.map((bucket) => ({
    label: thousands(bucket.from),
    band: `${formatUsd(bucket.from)} – ${formatUsd(bucket.to)}`,
    count: bucket.count,
  }))

  return (
    <div aria-hidden="true" style={{ width: '100%', height: 280 }}>
      <ResponsiveContainer width="100%" height="100%" initialDimension={{ width: 800, height: 280 }}>
        <BarChart data={data} margin={{ top: 8, right: 8, bottom: 8, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} />
          <XAxis dataKey="label" tickLine={false} />
          <YAxis tickFormatter={formatNumber} width={48} />
          <Tooltip
            formatter={(value) => [formatNumber(Number(value)), 'Employees']}
            labelFormatter={(_label, payload) => payload?.[0]?.payload?.band ?? ''}
          />
          <Bar dataKey="count" fill="#1d4f91" radius={[3, 3, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
