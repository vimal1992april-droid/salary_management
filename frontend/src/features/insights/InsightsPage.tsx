import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import DistributionSection from './DistributionSection'
import OutliersSection from './OutliersSection'
import OverviewCards from './OverviewCards'
import PayStatsSection from './PayStatsSection'
import TopEarnersSection from './TopEarnersSection'

/** How the organisation pays its people. Each section loads (and can fail) independently. */
export default function InsightsPage() {
  return (
    <>
      <Typography variant="h4" component="h1" gutterBottom>
        Insights
      </Typography>
      <Box sx={{ display: 'grid', gap: 3 }}>
        <OverviewCards />
        <PayStatsSection />
        <DistributionSection />
        <TopEarnersSection />
        <OutliersSection />
      </Box>
    </>
  )
}
