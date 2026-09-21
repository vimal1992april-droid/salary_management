import { Navigate, Route, Routes } from 'react-router-dom'
import AuthGate from './auth/AuthGate'
import LoginPage from './auth/LoginPage'
import AppLayout from './components/AppLayout'
import EmployeeDetailPage from './features/employees/EmployeeDetailPage'
import EmployeeFormPage from './features/employees/EmployeeFormPage'
import EmployeesPage from './features/employees/EmployeesPage'
import InsightsPage from './pages/InsightsPage'
import NotFoundPage from './pages/NotFoundPage'

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<AuthGate />}>
        <Route element={<AppLayout />}>
          <Route index element={<Navigate to="/employees" replace />} />
          <Route path="employees" element={<EmployeesPage />} />
          <Route path="employees/new" element={<EmployeeFormPage />} />
          <Route path="employees/:id" element={<EmployeeDetailPage />} />
          <Route path="employees/:id/edit" element={<EmployeeFormPage />} />
          <Route path="insights" element={<InsightsPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  )
}
