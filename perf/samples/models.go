package models

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

// --- Domain types ---

type Role string

const (
	RoleAdmin  Role = "admin"
	RoleEditor Role = "editor"
	RoleViewer Role = "viewer"
)

type UserID string

func NewUserID() UserID {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return UserID(hex.EncodeToString(b))
}

type User struct {
	ID        UserID    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	Role      Role      `json:"role"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (u *User) Validate() error {
	var errs []string
	if u.Name == "" {
		errs = append(errs, "name is required")
	}
	if !strings.Contains(u.Email, "@") {
		errs = append(errs, "invalid email")
	}
	switch u.Role {
	case RoleAdmin, RoleEditor, RoleViewer:
	default:
		errs = append(errs, fmt.Sprintf("unknown role: %s", u.Role))
	}
	if len(errs) > 0 {
		return fmt.Errorf("validation failed: %s", strings.Join(errs, "; "))
	}
	return nil
}

// --- Repository interface ---

type UserFilter struct {
	Query  string
	Role   *Role
	Limit  int
	Offset int
}

type UserRepository interface {
	Get(ctx context.Context, id UserID) (*User, error)
	List(ctx context.Context, filter UserFilter) ([]*User, int, error)
	Create(ctx context.Context, user *User) error
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id UserID) error
}

// --- In-memory implementation ---

var (
	ErrNotFound  = errors.New("user not found")
	ErrDuplicate = errors.New("duplicate email")
)

type MemoryRepo struct {
	mu    sync.RWMutex
	users map[UserID]*User
}

func NewMemoryRepo() *MemoryRepo {
	return &MemoryRepo{users: make(map[UserID]*User)}
}

func (r *MemoryRepo) Get(_ context.Context, id UserID) (*User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	u, ok := r.users[id]
	if !ok {
		return nil, ErrNotFound
	}
	return u, nil
}

func (r *MemoryRepo) List(_ context.Context, f UserFilter) ([]*User, int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var matched []*User
	q := strings.ToLower(f.Query)
	for _, u := range r.users {
		if f.Role != nil && u.Role != *f.Role {
			continue
		}
		if q != "" && !strings.Contains(strings.ToLower(u.Name), q) &&
			!strings.Contains(strings.ToLower(u.Email), q) {
			continue
		}
		matched = append(matched, u)
	}

	total := len(matched)
	if f.Offset > len(matched) {
		return nil, total, nil
	}
	matched = matched[f.Offset:]
	if f.Limit > 0 && len(matched) > f.Limit {
		matched = matched[:f.Limit]
	}
	return matched, total, nil
}

func (r *MemoryRepo) Create(_ context.Context, user *User) error {
	if err := user.Validate(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if strings.EqualFold(u.Email, user.Email) {
			return ErrDuplicate
		}
	}
	now := time.Now()
	user.CreatedAt = now
	user.UpdatedAt = now
	if user.ID == "" {
		user.ID = NewUserID()
	}
	r.users[user.ID] = user
	return nil
}

func (r *MemoryRepo) Update(_ context.Context, user *User) error {
	if err := user.Validate(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.users[user.ID]; !ok {
		return ErrNotFound
	}
	user.UpdatedAt = time.Now()
	r.users[user.ID] = user
	return nil
}

func (r *MemoryRepo) Delete(_ context.Context, id UserID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.users[id]; !ok {
		return ErrNotFound
	}
	delete(r.users, id)
	return nil
}
