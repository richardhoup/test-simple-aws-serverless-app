import { TodoList } from "@/components/todo-list"

export default function Home() {
  return (
    <main className="min-h-screen flex items-center justify-center p-4 bg-gray-50">
      <TodoList />
    </main>
  )
}
