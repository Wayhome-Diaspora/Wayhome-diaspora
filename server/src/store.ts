/// In-memory user store — tracks local role alongside BMONI user ID.
/// Replace with a real database before production.

export interface LocalUser {
  localId: string;
  bmoniUserId: string;
  role: 'sender' | 'recipient';
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  createdAt: Date;
}

class UserStore {
  private users = new Map<string, LocalUser>();
  private bmoniIndex = new Map<string, LocalUser>(); // bmoniUserId → LocalUser

  create(params: {
    bmoniUserId: string;
    role: 'sender' | 'recipient';
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
  }): LocalUser {
    const localId = `local_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const user: LocalUser = {
      localId,
      ...params,
      createdAt: new Date(),
    };
    this.users.set(localId, user);
    this.bmoniIndex.set(params.bmoniUserId, user);
    return user;
  }

  getByBmoniId(bmoniUserId: string): LocalUser | undefined {
    return this.bmoniIndex.get(bmoniUserId);
  }

  getByLocalId(localId: string): LocalUser | undefined {
    return this.users.get(localId);
  }
}

export const userStore = new UserStore();
