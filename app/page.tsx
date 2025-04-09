import { TodoList } from "@/components/todo-list"

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-50 py-4 px-2">
      <div className="container mx-auto max-w-sm">
        <TodoList />
      </div>
    </main>
  )
}
