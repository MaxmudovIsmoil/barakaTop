<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserPriv extends Model
{
    use HasFactory;

    protected $table = 'user_priv';

    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'action_id',
        'access',
    ];

    public function action()
    {
        return $this->hasMany(ActionModal::class, 'id', 'ation_id');
    }
}
