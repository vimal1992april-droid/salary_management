import { useQuery } from '@tanstack/react-query'
import { getDistribution, getOutliers, getOverview, getPayStats, getTopEarners, type GroupBy } from '../../api/insights'

export const useOverview = () => useQuery({ queryKey: ['insights', 'overview'], queryFn: getOverview })

export const usePayStats = (groupBy: GroupBy) =>
  useQuery({ queryKey: ['insights', 'pay-stats', groupBy], queryFn: () => getPayStats(groupBy) })

export const useDistribution = () => useQuery({ queryKey: ['insights', 'distribution'], queryFn: () => getDistribution() })

export const useTopEarners = (direction: 'asc' | 'desc') =>
  useQuery({ queryKey: ['insights', 'top-earners', direction], queryFn: () => getTopEarners(direction) })

export const useOutliers = () => useQuery({ queryKey: ['insights', 'outliers'], queryFn: () => getOutliers() })
