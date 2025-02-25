import React, { useState, useEffect } from 'react';
import { read, utils } from 'xlsx';
import toast from 'react-hot-toast';
import { supabase } from '../lib/supabase';
import { Movie } from '../types/Movie';
import { format } from 'date-fns';
import { Home, Upload, Trash2, Clock, Plus, AlertTriangle } from 'lucide-react';
import { Link } from 'react-router-dom';

const ADMIN_PASSWORD = '121212';

interface MovieFormData {
  Data: string;
  'ID Film TMDb': string;
  'Orario Inizio': string;
  'Orario Fine': string;
  Lingua: string;
  Sottotitoli: string;
  'Pretix Event ID': string;
  Titolo: string;
}

interface EditingMark {
  id: number;
  value: string;
}

const Admin = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [password, setPassword] = useState('');
  const [movies, setMovies] = useState<Movie[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<'all' | 'past' | null>(null);
  const [editingMark, setEditingMark] = useState<EditingMark | null>(null);
  const [newMovie, setNewMovie] = useState<MovieFormData>({
    Data: '',
    'ID Film TMDb': '',
    'Orario Inizio': '',
    'Orario Fine': '',
    Lingua: '',
    Sottotitoli: '',
    'Pretix Event ID': '',
    Titolo: ''
  });
  const [previewData, setPreviewData] = useState<any[]>([]);
  const [showPreview, setShowPreview] = useState(false);

  useEffect(() => {
    if (isAuthenticated) {
      fetchMovies();
    }
  }, [isAuthenticated]);

  const fetchMovies = async () => {
    const { data, error } = await supabase
      .from('movies2')
      .select('*')
      .order('Data', { ascending: true })
      .order('Orario Inizio', { ascending: true });

    if (error) {
      toast.error('Error fetching movies');
      return;
    }

    setMovies(data);
    setLoading(false);
  };

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (password === ADMIN_PASSWORD) {
      setIsAuthenticated(true);
      toast.success('Login successful');
    } else {
      toast.error('Invalid password');
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (e) => {
      try {
        const data = new Uint8Array(e.target?.result as ArrayBuffer);
        const workbook = read(data, { type: 'array' });
        const worksheet = workbook.Sheets[workbook.SheetNames[0]];
        const jsonData = utils.sheet_to_json(worksheet);
        setPreviewData(jsonData);
        setShowPreview(true);
      } catch (error) {
        toast.error('Error processing file');
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const confirmUpload = async () => {
    try {
      const { error } = await supabase.from('movies2').insert(previewData);

      if (error) {
        toast.error('Error uploading data');
        return;
      }

      toast.success('Data uploaded successfully');
      setShowPreview(false);
      setPreviewData([]);
      fetchMovies();
    } catch (error) {
      toast.error('Error uploading data');
    }
  };

  const handleDeletePast = async () => {
    try {
      const now = new Date();
      const currentDate = format(now, 'yyyy-MM-dd');
      const currentTime = format(now, 'HH:mm');

      // First, delete movies from past dates
      const { error: pastError } = await supabase
        .from('movies2')
        .delete()
        .lt('Data', currentDate);

      if (pastError) {
        console.error('Error deleting past dates:', pastError);
        toast.error('Error deleting past movies');
        return;
      }

      // Then, delete movies from today that have ended
      const { error: todayError } = await supabase
        .from('movies2')
        .delete()
        .eq('Data', currentDate)
        .lte('Orario Fine', currentTime);

      if (todayError) {
        console.error('Error deleting today\'s past movies:', todayError);
        toast.error('Error deleting past movies');
        return;
      }

      toast.success('Past movies deleted successfully');
      setShowDeleteConfirm(null);
      fetchMovies();
    } catch (error) {
      console.error('Error:', error);
      toast.error('Error deleting past movies');
    }
  };

  const handleDeleteAll = async () => {
    const { error } = await supabase.from('movies2').delete().neq('id', 0);

    if (error) {
      toast.error('Error deleting all movies');
      return;
    }

    toast.success('All movies deleted successfully');
    setShowDeleteConfirm(null);
    fetchMovies();
  };

  const handleDeleteMovie = async (id: number) => {
    const { error } = await supabase.from('movies2').delete().eq('id', id);

    if (error) {
      toast.error('Error deleting movie');
      return;
    }

    toast.success('Movie deleted successfully');
    fetchMovies();
  };

  const handleToggleSoldOut = async (id: number, currentStatus: boolean) => {
    const { error } = await supabase
      .from('movies2')
      .update({ 'Sold Out': !currentStatus })
      .eq('id', id);

    if (error) {
      toast.error('Error updating sold out status');
      return;
    }

    toast.success('Status updated successfully');
    fetchMovies();
  };

  const handleUpdateMark = async (id: number, mark: string) => {
    const { error } = await supabase
      .from('movies2')
      .update({ Mark: mark })
      .eq('id', id);

    if (error) {
      toast.error('Error updating mark');
      return;
    }

    toast.success('Mark updated successfully');
    setEditingMark(null);
    fetchMovies();
  };

  const handleAddMovie = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const { error } = await supabase.from('movies2').insert([newMovie]);

      if (error) {
        toast.error('Error adding movie');
        return;
      }

      toast.success('Movie added successfully');
      setShowAddModal(false);
      setNewMovie({
        Data: '',
        'ID Film TMDb': '',
        'Orario Inizio': '',
        'Orario Fine': '',
        Lingua: '',
        Sottotitoli: '',
        'Pretix Event ID': '',
        Titolo: ''
      });
      fetchMovies();
    } catch (error) {
      toast.error('Error adding movie');
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gray-100 p-8">
        <div className="max-w-md mx-auto mt-20">
          <form onSubmit={handleLogin} className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-2xl font-bold mb-4">Admin Login</h2>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              className="w-full p-2 border rounded mb-4"
            />
            <button
              type="submit"
              className="w-full bg-black text-white py-2 rounded hover:bg-gray-900"
            >
              Login
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="fixed top-4 right-4 z-50">
        <Link 
          to="/"
          className="flex items-center justify-center w-10 h-10 bg-white rounded-full hover:bg-gray-100 transition-colors"
        >
          <Home className="w-5 h-5 text-gray-900" />
        </Link>
      </div>
      
      <div className="max-w-7xl mx-auto space-y-8">
        {/* Action Buttons */}
        <div className="flex flex-wrap gap-4">
          <button
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-black text-white rounded-lg hover:bg-gray-900"
          >
            <Plus className="w-4 h-4" />
            Add Movie
          </button>
          <label className="flex items-center gap-2 px-4 py-2 bg-black text-white rounded-lg hover:bg-gray-900 cursor-pointer">
            <Upload className="w-4 h-4" />
            Upload Excel
            <input
              type="file"
              accept=".xlsx,.xls"
              onChange={handleFileUpload}
              className="hidden"
            />
          </label>
          <button
            onClick={() => setShowDeleteConfirm('past')}
            className="flex items-center gap-2 px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700"
          >
            <Clock className="w-4 h-4" />
            Delete Past Movies
          </button>
          <button
            onClick={() => setShowDeleteConfirm('all')}
            className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            <Trash2 className="w-4 h-4" />
            Delete All Movies
          </button>
        </div>

        {/* Movies Table */}
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Title
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Time
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Mark
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {movies.map((movie) => (
                  <tr key={movie.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      {format(new Date(movie.Data), 'dd/MM/yyyy')}
                    </td>
                    <td className="px-6 py-4">{movie.Titolo}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {movie['Orario Inizio']} - {movie['Orario Fine']}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        {editingMark?.id === movie.id ? (
                          <>
                            <input
                              type="text"
                              value={editingMark.value}
                              onChange={(e) => setEditingMark({ id: movie.id, value: e.target.value })}
                              className="w-full border rounded px-2 py-1"
                              placeholder="Add mark..."
                            />
                            <button
                              onClick={() => handleUpdateMark(movie.id, editingMark.value)}
                              className="px-2 py-1 bg-green-100 text-green-800 rounded hover:bg-green-200"
                            >
                              Save
                            </button>
                            <button
                              onClick={() => setEditingMark(null)}
                              className="px-2 py-1 bg-gray-100 text-gray-800 rounded hover:bg-gray-200"
                            >
                              Cancel
                            </button>
                          </>
                        ) : (
                          <div 
                            className="w-full flex items-center justify-between gap-2 cursor-pointer hover:bg-gray-50 p-2 rounded"
                            onClick={() => setEditingMark({ id: movie.id, value: movie.Mark || '' })}
                          >
                            <span className="flex-grow">{movie.Mark || 'Click to add mark...'}</span>
                            <span className="text-gray-400 text-sm">(click to edit)</span>
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleToggleSoldOut(movie.id, movie['Sold Out'])}
                          className={`px-3 py-1 rounded ${
                            movie['Sold Out']
                              ? 'bg-green-100 text-green-800'
                              : 'bg-red-100 text-red-800'
                          }`}
                        >
                          {movie['Sold Out'] ? 'Available' : 'Sold Out'}
                        </button>
                        <button
                          onClick={() => handleDeleteMovie(movie.id)}
                          className="px-3 py-1 bg-red-100 text-red-800 rounded hover:bg-red-200"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Add Movie Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <h2 className="text-2xl font-bold mb-4">Add New Movie</h2>
            <form onSubmit={handleAddMovie} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Date</label>
                <input
                  type="date"
                  required
                  value={newMovie.Data}
                  onChange={(e) => setNewMovie({ ...newMovie, Data: e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">TMDb ID</label>
                <input
                  type="text"
                  required
                  value={newMovie['ID Film TMDb']}
                  onChange={(e) => setNewMovie({ ...newMovie, 'ID Film TMDb': e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Start Time</label>
                  <input
                    type="time"
                    required
                    value={newMovie['Orario Inizio']}
                    onChange={(e) => setNewMovie({ ...newMovie, 'Orario Inizio': e.target.value })}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">End Time</label>
                  <input
                    type="time"
                    required
                    value={newMovie['Orario Fine']}
                    onChange={(e) => setNewMovie({ ...newMovie, 'Orario Fine': e.target.value })}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Language</label>
                <input
                  type="text"
                  required
                  value={newMovie.Lingua}
                  onChange={(e) => setNewMovie({ ...newMovie, Lingua: e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Subtitles</label>
                <input
                  type="text"
                  value={newMovie.Sottotitoli}
                  onChange={(e) => setNewMovie({ ...newMovie, Sottotitoli: e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Pretix Event ID</label>
                <input
                  type="text"
                  required
                  value={newMovie['Pretix Event ID']}
                  onChange={(e) => setNewMovie({ ...newMovie, 'Pretix Event ID': e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Title</label>
                <input
                  type="text"
                  required
                  value={newMovie.Titolo}
                  onChange={(e) => setNewMovie({ ...newMovie, Titolo: e.target.value })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-black focus:ring-black"
                />
              </div>
              <div className="flex gap-4 pt-4">
                <button
                  type="submit"
                  className="flex-1 bg-black text-white py-2 rounded-lg hover:bg-gray-900"
                >
                  Add Movie
                </button>
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 bg-gray-100 text-gray-700 py-2 rounded-lg hover:bg-gray-200"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <div className="flex items-center gap-4 mb-4 text-red-600">
              <AlertTriangle className="w-8 h-8" />
              <h2 className="text-2xl font-bold">Confirm Delete</h2>
            </div>
            <p className="text-gray-600 mb-6">
              {showDeleteConfirm === 'all' 
                ? 'Are you sure you want to delete all movies? This action cannot be undone.'
                : 'Are you sure you want to delete all past movies? This action cannot be undone.'}
            </p>
            <div className="flex gap-4">
              <button
                onClick={() => showDeleteConfirm === 'all' ? handleDeleteAll() : handleDeletePast()}
                className="flex-1 bg-red-600 text-white py-2 rounded-lg hover:bg-red-700"
              >
                Delete
              </button>
              <button
                onClick={() => setShowDeleteConfirm(null)}
                className="flex-1 bg-gray-100 text-gray-700 py-2 rounded-lg hover:bg-gray-200"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Excel Preview Modal */}
      {showPreview && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-4xl w-full p-6">
            <h2 className="text-2xl font-bold mb-4">Preview Data</h2>
            <div className="max-h-[60vh] overflow-y-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    {Object.keys(previewData[0] || {}).map((key) => (
                      <th key={key} className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        {key}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {previewData.map((row, index) => (
                    <tr key={index}>
                      {Object.values(row).map((value: any, i) => (
                        <td key={i} className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {value?.toString()}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="flex gap-4 mt-6">
              <button
                onClick={confirmUpload}
                className="flex-1 bg-black text-white py-2 rounded-lg hover:bg-gray-900"
              >
                Confirm Upload </button>
              <button
                onClick={() => {
                  setShowPreview(false);
                  setPreviewData([]);
                }}
                className="flex-1 bg-gray-100 text-gray-700 py-2 rounded-lg hover:bg-gray-200"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Admin;